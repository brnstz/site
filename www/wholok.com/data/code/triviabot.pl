#!/usr/bin/perl -w

use Trivia;
use Net::IRC;
use strict;


my $irc = new Net::IRC;

# this object abstracts the database and trivia operations
my $trivia = new Trivia;


# by using shifts here, we can overload the default server, port, and channel
# with command-line args
my $conn = $irc->newconn(
	Server 		=> shift || 'turtle.wholok.com',
	Port		=> shift || '80',
	Nick		=> 'TriviaBot',
	Ircname		=> 'I will stump you!',
	Username	=> 'trivia'
);

# save the trivia object inside of the connect object to pass around easily.
$conn->{trivia} = $trivia;

$conn->{channel} = shift || '##';


sub on_connect {

	my $conn = shift;
  	
	# join our channel
	$conn->join($conn->{channel});
	
	# greet the people in the channel
	$conn->privmsg($conn->{channel}, 'booya!  it\'s Trivia time!');
}


sub on_public {

	
	# two args are passed on events, the connection object and a
	# hash that describes the event
	my ($conn, $event) = @_;
	
	# this is the text of the event, eg, what the person said
	my $text = $event->{args}[0];

	# we first check to see if it's a command (if it starts with !)
	if ($text =~ /^\!(.+)$/) {
		on_public_command($conn, $1, $event->{nick});
	}
	# otherwise, we assume it's a guess to the current question
	else {
		# check the answers
		my $res = $conn->{trivia}->check_answer($event->{nick}, $text);
		# if we've got the right answer, then celebrate
		if ($res) {
			on_answer($conn, $res, $event->{nick});
		}
		# otherwise, repeat the current hint
		else {
			repeat_hint($conn);
		}	
			
	}
}

sub repeat_question {

	my $conn = shift;
	
	# print the current question out to the channel
	$conn->privmsg($conn->{channel}, $conn->{trivia}{cur_question});
	
}

sub repeat_hint {

	my $conn = shift;
	
	# if the last guess resulted in an updated hint, then repeat
	# the hint
	if ($conn->{trivia}->{updated_hint}) {
		$conn->privmsg($conn->{channel}, $conn->{trivia}{cur_hint});
	}	

}	

sub on_public_command {
	
	
	# here, we get the connection object, the text of the command, and
	# the nick of the person who issued the command
	my ($conn, $command, $nick) = @_;

	# branch off given the nature of the command
	$_ = $command;
	COM: {
		# this turns trivia on
		if (/^trivon$/) {
			
			# don't turn on trivia unless it's off
			if ($conn->{trivia}{status} ne '') {
				last COM;
			}
			
			# set status to wait 10 seconds
			$conn->{trivia}{status} = 'waiting';
			# alert users that trivia is starting
			$conn->privmsg($conn->{channel}, "Trivia is on!  First question in 10 seconds.");
			# save the current timestamp
			$conn->{newtime} = time;
			# set the amount we've waited to 0
			$conn->{waittime} = 0;
			last COM;
		
		}
		if (/^trivoff$/) {
			# set status to nothing	
			$conn->{trivia}{status} = '';
			# tell everyone that trivia over
			$conn->privmsg($conn->{channel}, "Trivia is off!");
			last COM;	
		}
		if (/^score$/) {
			# we want to see the scores, so let's have 'em
			handle_score($conn);
			last COM;
		}	
	}	
}

sub handle_score {

	my $conn = shift;

	# get a hash ref to the score from the trivia object
	my $score_ref = $conn->{trivia}->get_score();
	
	# announce that we're going to the print the score
	$conn->privmsg($conn->{channel}, "Score:");

	# print everyone's score
	foreach (@$score_ref) {
		# make $_ a real hash, so it's easier to print
		my %hash = %$_;
		$conn->privmsg($conn->{channel}, "$hash{nick}: $hash{score}");
	}
}

sub on_answer {
	
	my ($conn, $answer, $nick) = @_;

	# set status to wait 10 seconds again, announce winner of question
	$conn->{trivia}{status} = 'waiting';
	$conn->privmsg($conn->{channel}, "Correct answer by $nick!");
	$conn->privmsg($conn->{channel}, $answer);
	$conn->privmsg($conn->{channel}, "Next question in 10 seconds");

	# set the latest time to timestamp for the delay
	$conn->{newtime} = time;
}

sub handle_waiting {

	my $conn = shift;
	
	# set old time to new time
	$conn->{oldtime} = $conn->{newtime};
	# set new time to now
	$conn->{newtime} = time;
	# how much time has past since we were here?
	my $secs = $conn->{newtime} - $conn->{oldtime};
	
	# how much time has past since we last reset the clock?
	$conn->{waittime} += $secs;

	# if we've waited more than 10 seconds, change our status to
	# getquestion and reset waittime
	if ($conn->{waittime} > 10) {
		$conn->{trivia}{status} = 'getquestion';
		$conn->{waittime} = 0;
	}

}

sub handle_trivia_loop {

	my $conn = shift;

	
	$_ = $conn->{trivia}{status};
	STATUS: {
		if (/^getquestion$/) {
			# get question from trivia object
			$conn->{trivia}->get_question();
			# say the question, and show the hint
			repeat_question($conn);
			repeat_hint($conn);
			last STATUS;
		}
		if (/^waiting$/) {
			handle_waiting($conn);
			last STATUS;
		}
	}

}

# we handle only 2 events, public messages and connecting
$conn->add_handler('public', \&on_public);
$conn->add_handler('376', \&on_connect);


# while forever, handle_trivia, then do an IRC loop
while (1) {
	
	handle_trivia_loop($conn);
	$irc->do_one_loop();
}	
