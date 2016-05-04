#!/usr/bin/perl -w

use Net::IRC;
use strict;

# create the IRC object
my $irc = new Net::IRC;

# Create a connection object.  You can have more than one "connection" per
# IRC object, but we'll just be working with one.
my $conn = $irc->newconn(
	Server 		=> shift || 'turtle.wholok.com',
	# Note: IRC port is normally 6667, but my firewall won't allow it	
	Port		=> shift || '80', 
	Nick		=> 'HelloBot',
	Ircname		=> 'I like to greet!',
	Username	=> 'hello'
);

# We're going to add this to the conn hash so we know what channel we
# want to operate in.
$conn->{channel} = shift || '##';

sub on_connect {

	# shift in our connection object that is passed automatically
	my $conn = shift;
  
	# when we connect, join our channel and greet it
	$conn->join($conn->{channel});
	$conn->privmsg($conn->{channel}, 'Hello everyone!');
	$conn->{connected} = 1;

}

sub on_join {

	# get our connection object and the event object, which is passed
	# with this event automatically
	my ($conn, $event) = @_;

	# this is the nick that just joined
	my $nick = $event->{nick};
	# say hello to the nick in public
	$conn->privmsg($conn->{channel}, "Hello, $nick!");
}
	
sub on_part {
	
	# pretty much the same as above

	my ($conn, $event) = @_;

	my $nick = $event->{nick};
	$conn->privmsg($conn->{channel}, "Goodbye, $nick!");
}

# add event handlers for join and part events
$conn->add_handler('join', \&on_join);
$conn->add_handler('part', \&on_part);

# The end of MOTD (message of the day), numbered 376 signifies we've connect
$conn->add_handler('376', \&on_connect);

# start IRC
$irc->start();
