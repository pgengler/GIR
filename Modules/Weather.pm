package Modules::Weather;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use LWP::Simple;
use XML::Simple;

#######
## GLOBALS
#######
my $CACHE_TIME = 15;	# time to cache (in minutes)

my $base_url = 'http://www.weather.gov/data/current_obs/';

my %cache;

##############
sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	&Modules::register_action('weather', \&Modules::Weather::process);
	&Modules::register_help('weather', \&Modules::Weather::help);
}

sub process()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	unless ($data && $data =~ /^\w{4}$/) {
		return;
	}

	# Check if we have cached data, and it's still valid
	if ($cache{ $data } && $cache{ $data }->{'retrieved'} + ($CACHE_TIME * 60) > time()) {
		return $cache{ $data }->{'weather'};
	}

	my $text = &get($base_url . $data . '.xml');

	unless ($text) {
		return 'Something failed in contacting the NOAA server.';
	}

	if ($text !~ /\</) {
		return $text;
	}

	my $xml = new XML::Simple;
	my $doc = $xml->xml_in($text);

	my $heat_index = (!$doc->{'heat_index_f'} || $doc->{'heat_index_f'} eq 'NA') ? '' : "Heat index: $doc->{'heat_index_string'}. ";
	my $wind_chill = (!$doc->{'windchill_f'} || $doc->{'windchill_f'} eq 'NA') ? '' : "Wind chill: $doc->{'windchill_string'}. ";

	my $weather = "Current conditions for $doc->{'location'} ($doc->{'station_id'}). $doc->{'observation_time'}. Sky conditions: $doc->{'weather'}. Temperature: $doc->{'temperature_string'}, dewpoint: $doc->{'dewpoint_string'}. ${heat_index}${wind_chill}Relative humidity: $doc->{'relative_humidity'}%. Pressure: $doc->{'pressure_string'}. Winds: $doc->{'wind_string'}. Visibility: $doc->{'visibility_mi'} mile(s).";

	my %info = (
		'retrieved' => time(),
		'weather'   => $weather
	);
	$cache{ $data } = \%info;
	return $weather;
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "Usage: weather <airport code>\nReturns a formatted string with the latest weather observation for the given airport. Not all airports have weather reporting though most major ones do.";
}

1;
