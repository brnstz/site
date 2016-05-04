package WeatherParse;

use HTML::Parser;
@ISA = qw(HTML::Parser);

use strict;



sub new {

	my $pkg = shift;

	my $obj = HTML::Parser::new($pkg); 
	
	$obj->reinit();

	return $obj;
}

sub reinit {
	
	my $obj = shift;

	$obj->{status} = '';
	$obj->{listener} = 0;
	$obj->{text} = '';

	$obj->{main_array} = [];
	$obj->{forecast_array} = [];


}	

sub start {
	
	my ($obj, $tag, $attr, $attrseq, $origtext) = @_;

	if (!$obj->{status}) { return; }

	if ($tag eq 'td') {
		$obj->{listener} = 1;
	}

}

sub end {

	my ($obj, $tag, $origtext) = @_;

	if (!$obj->{status}) { return; }

	if ($tag eq 'td') {
		$obj->{listener} = 0;
		$obj->pusher();
	}

}

sub text {

	my ($obj, $text) = @_;
	
	$obj->status_deter($text);

	if ($obj->{listener}) {
		$obj->{text} .= $text;
	}

}

sub status_deter {
	
	my ($obj, $text) = @_;
	
	if ($text =~ /Updated\:/) {
		$obj->{status} = 'main';
	}
	
	if ($text =~ /Forecast as of/) {
		$obj->{status} = 'forecast';
	}

}

sub pusher {

	my $obj = shift;

	# only add if there's any word chars here
	if ($obj->{text} =~ /\w+/) { 
		
		#replace multiple spaces with one space
		$obj->{text} =~ s/\s{2,}/ /g;
	
		#replace single spaces after periods with two spaces
		$obj->{text} =~ s/\. (\w)/\.  $1/g;
	
		#replace HTML degrees with nada 
		$obj->{text} =~ s/\&\#176\;//;
	
		push(@{$obj->{$obj->{status} . '_array'}}, $obj->{text});
	}	
	$obj->{text} = '';
}
