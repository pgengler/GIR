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

	if ($data && $data =~ /^(\w{4})\s*$/) {
		$data = $1;
	} else {
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

	# This maps the string to be included in the output to the name of the value in the XML document.
	# The number before the pipe (|) in the 'text' string is its position in the result string.
	# A trailing colon (:) after the string and a period after the whole item will be added automatically.
	# If a pipe (|) is included, any text after it will be appended to the string, before the period.
	my %components = (
		'1|Sky conditions'    => 'weather',
		'2|Temperature'       => 'temperature_string',
		'3|Dewpoint'          => 'dewpoint_string',
		'4|Heat index'        => 'heat_index_string',
		'5|Wind chill'        => 'windchill_string',
		'6|Relative humidity' => 'relative_humidity|%',
		'7|Pressure'          => 'pressure_string',
		'8|Winds'             => 'wind_string',
		'9|Visibility'        => 'visibility_mi| mile(s)'
	);

	my $weather = "Current conditions for $doc->{'location'} ($doc->{'station_id'}). $doc->{'observation_time'}. ";

	foreach my $text (sort { $a cmp $b } keys %components) {
		my $ref    = $components{ $text };
		my $append = '';
		$text      =~ s/\d+\|//;
		if ($ref =~ /(.+)\|(.+)/) {
			$ref = $1;
			$append = $2;
		}
		my $value = $doc->{ $ref };

		if ($value) {
			$weather .= sprintf("%s: %s%s. ", $text, $value, $append);
		}
	}

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
