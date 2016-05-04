#!/usr/bin/perl -w

use Net::IRC;
use strict;
use Data::Dumper;
use WeatherGet;
use Text::Wrapper;
use vars qw($weather $wrapper);

# create a WeatherGet object (downloads and parses weather from
# weatherunderground.com)
$weather = new WeatherGet;

# text wrapper to wrap long messages at the approximate length an IRC
# message should be, at its longest
$wrapper = new Text::Wrapper(columns => 400);

my $irc = new Net::IRC;

my $conn = $irc->newconn(
	Server 		=> shift || 'turtle.wholok.com',
	Port		=> shift || '80',
	Nick		=> 'RokerBot',
	Ircname		=> '!roker city, state',
	Username	=> 'roker'
);

$conn->{channel} = shift || '##';

sub on_connect {

	my $conn = shift;
  
  	# when we connect, join our channel and greet it
	$conn->join($conn->{channel});
	$conn->privmsg($conn->{channel}, 'booya!  it\'s Roker time!');
}

sub on_public {

	# on an event, we get connection object and event hash
	my ($conn, $event) = @_;

	# this is what was said in the event
	my $text = $event->{args}[0];
	
	# regex the text to see if it begins with !roker
	if ($text =~ /^\!roker (.+)/) {
		
		# if so, pass the text and the nick off to the weather method
		my $weather_text = weather($1, $event->{nick});
	
		# wrap text at 400 chars (about as much as you should put
		# into a single IRC message
		my $wrapped_text = $wrapper->wrap($weather_text);
		my @texts = split("\n", $wrapped_text);
		
		# $event->{to}[0] is the channel where this was said
		foreach (@texts) {
			$conn->privmsg($event->{to}[0], $_);
		}	
	}
}


sub on_msg {
	my ($conn, $event) = @_;

	# This is a *really* hacky part.  I usually use this bot on an IRC
	# server that doesn't send the end of MOTD that signifies connect, so
	# I use this to simulate the connect.
	#
	# It basically says "if someone with my nick /msg you with 'join',
	# then you've connected"
	if (
	($event->{nick} eq 'wholok') and
	($event->{args}[0] eq 'join')){
		on_connect($conn);
	}
	
	# Under normal circumstances, simply reply to the nick that there's
	# no reason to /msg RokerBot.
	else {	
		$conn->privmsg($event->{nick}, "Don't nobody /msg RokerBot.");
	}
	
}

sub on_notice {

	my ($conn, $event) = @_;

	# This handles nick registration.  On some IRC networks, you can 
	# password-protect you nick.  The IRC server will send you a "notice"
	# as NickServ that you have to identify with your passowrd.
	if (
	($event->{nick} eq 'NickServ') and
	($event->{args}[0] eq 'If you do not change within one minute, I will change your nick.')
	) {
		# send an /msg to NickServ with the password
		$conn->privmsg('NickServ', 'identify rokerman');
		
		# This is another hack, based on the fact that I've registered
		# the nick "RokerBot" on the IRC server which doesn't
		# send the end of MOTD message.  So when I'm asked to 
		# send my password, I know I've connected.
		#
		# This is redundant with the behavior covered in on_msg
		on_connect($conn);
	}
}

sub weather {

	my $input = shift;
	my $nick = shift;
	
	# Split the text sent on a comma and space, eg "New York, NY"
	my ($city, $state) = split(', ', $input);
	
	# Get weather information from the weather object
	if ($weather->get_weather($city, $state)) {
		# If we get true from this, then we've failed and will
		# return an error message
		return "Unable to retrieve weather.  Sorry, $nick.";
	}	
	
	# otherwise, we get a hash of today's forecast and an array
	# of future days forecasts.
	
	my %wh = %{$weather->{main}};
	my @dh = @{$weather->{forecast}};
	
	# format today's forecast
	my $text = qq/$nick, it's $wh{Temperature} in $city, $state right now.  Wind is $wh{Wind}.  Humidity is $wh{Humidity}.  Roker would say it's $wh{Conditions}.  /;
	# give the next two days' forecasts
	foreach (0..1) {
		$text .= $dh[$_];
	}	
	
	return $text;
}
	

sub default {

	# This is helpful to see what an event returns.  Data::Dumper will
	# recursively reveal the structure of any value
	my ($conn, $event) = @_;
	print Dumper($event);
}
	


# add handlers for our standard events
$conn->add_handler('public', \&on_public);
$conn->add_handler('msg', \&on_msg);
$conn->add_handler('notice', \&on_notice);
$conn->add_handler('376', \&on_connect);

# experiment with the cping event, printing out to standard output
$conn->add_handler('cping', \&default);

# start IRC
$irc->start;
