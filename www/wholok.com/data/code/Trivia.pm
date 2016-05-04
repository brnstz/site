package Trivia;

use DBI;
use strict;

sub new {

	my ($pkg) = shift;

	# Things to pass to hash:
	# db => db name
	# host => db host
	# user => db user name
	# password => db password
	# table => db table
	#
	# Example:
	# my $trivia = new Trivia(db => 'mydb', host => 'unlocalhost.com');
	
	my %hash = @_;
	
	
	my $obj = bless \%hash, $pkg;

	$obj->{status} = '';
	$obj->db_connect();
	
	return $obj;

}

sub db_connect {

	my $obj = shift;

	# check if db is up
	if ($obj->{dbh}) {
		if ($obj->{dbh}->ping()) {
			return;
		}	
	}
	
	my $db = $obj->{db} || 'trivia';
	my $host = $obj->{host} || 'localhost';
	my $user = $obj->{user} || 'triviabot';
	my $password = $obj->{password} || 'super902soaker';

	my $dbh = DBI->connect("DBI:mysql:$db:$host", $user, $password);  
	
	if (!$dbh) {
		die("Can't connect to $db with $user $password");
	}	

	$obj->{dbh} = $dbh;
}

sub db_disconnect {

	my $obj = shift;
	$obj->{dbh}->disconnect();

}

sub min {
	
	my ($a, $b) = @_;
	
	if ($a < $b) { return $a; }
	else { return $b;}

}	

sub reset_question {

	my $obj = shift;
	
	$obj->{cur_question} = '';
	$obj->{cur_answer} = '';
	$obj->{cur_hint} = '';
	$obj->{status} = 'waiting';

}

sub update_hint {

	my $obj = shift;
	my $attempt = shift;

	my @hint = split('', $obj->{cur_hint});
	my @attempt = split('', $attempt);
	my @answer = split('', $obj->{cur_answer});

	 $obj->{updated_hint} = '';
	
	my $i;
	for ($i = 0; $i <= min($#attempt, $#answer); $i++) {
		if ($attempt[$i] =~ /\Q$answer[$i]\E/i) {
			$hint[$i] = $answer[$i];
		}
	}		
	
	my $old_hint = $obj->{cur_hint};

	$obj->{cur_hint} = join('', @hint);
	
	if ($old_hint ne $obj->{cur_hint}) {
		$obj->{updated_hint} = 1;
	}	
}	



sub get_question {

	my $obj = shift;

	my $table = $obj->{table} || 'trivia';
	
	my $statement = qq/SELECT * FROM $table ORDER BY RAND() LIMIT 1/;
	my $ans = $obj->{dbh}->selectrow_hashref($statement);

	if (!$ans) {
		die("Can't get question from database");
	}
	
	$obj->{cur_question} = $ans->{question};
	$obj->{cur_answer} = $ans->{answer};
	
	# initialize hint to all alphanumeric -> *
	$obj->{cur_hint} = $ans->{answer};
	$obj->{cur_hint} =~ s/\w/\*/g;

	$obj->{status} = 'question';
	$obj->{updated_hint} = 1;

}

sub update_score {

	my $obj = shift;
	my $nick = shift;
	my $add = shift;

	my $statement = qq/UPDATE scores SET score = score + $add WHERE nick = "$nick"/;
	my $ret = $obj->{dbh}->do($statement);
	# if nick is not in database, then add him
	if ($ret != 1) {
		$statement = qq/INSERT INTO scores SET nick = "$nick", score = $add/;
		$obj->{dbh}->do($statement);
	}
}	

sub get_score {

	my $obj = shift;
	
	return $obj->{dbh}->selectall_hashref("SELECT * FROM scores");
}

sub check_answer {

	my $obj = shift;
	my $nick = shift;
	my $attempt = shift;

	# don't allow multiple people to answer same question
	if ($obj->{status} ne 'question') { return; }

	# check if attempt *contains* answer, case insensitive
	if ($attempt =~ /\Q$obj->{cur_answer}\E/i) {
		
		#$obj->{scores}{$nick}++;
		$obj->update_score($nick, 1);
		
		my $ans = $obj->{cur_answer}; # save before resetting
		$obj->reset_question();
		return $ans;
	}
	else {
		$obj->update_hint($attempt);
		return 0;
	}
}
1;
