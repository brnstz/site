package WeatherGet;

use LWP;
use WeatherParse;
use Data::Dumper;
use strict;
use vars qw($ua $wp);

$ua = new LWP::UserAgent;
$ua->agent("Mozilla/5.0 (compatible; RokerBot 0.1; RokerOS 0.1)");

$wp = new WeatherParse;

sub new {

	my $pkg = shift;
	return bless {}, $pkg;

}

sub get_weather {
	
	my $obj = shift;
	my $city = shift;
	my $state = shift;

	$city =~ s/\ /\_/g;

	if (!($city or $state)) { return "No city or state!"; }

	my $url = "http://www.weatherunderground.com/auto/roker/$state/$city.html";
	
	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);
	
	if ($resp->is_success) {
		return $obj->parse_response($resp->content)
	}
	else {
		return "Unknown error!";
	}
	
}
sub parse_response {

	my $obj = shift;
	my $content = shift;

	$wp->parse($content);
		
	my @main = @{$wp->{main_array}};
	my @forecast = @{$wp->{forecast_array}};

	$wp->reinit();

	if (!@main) {
		return 1;
	}	
	
	my %main = @main[0..15];
	
	$obj->{main} = \%main;
	$obj->{forecast} = \@forecast;
	
	return 0;
}
