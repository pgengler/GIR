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

my $urlTemplate = 'http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml?query=%s';

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

sub process($)
{
	my $message = shift;

	my $station = $message->message();

	return unless $station;

	# Check if we have cached data, and it's still valid
	if ($cache{ $station } && $cache{ $station }->{'retrieved'} + ($CACHE_TIME * 60) > time()) {
		return $cache{ $station }->{'weather'};
	}

	&Bot::status("Looking up weather for '$station'") if $Bot::config->{'debug'};

	my $text = &get(sprintf($urlTemplate, $station));

	unless ($text) {
		return 'Something failed in contacting the weather server.';
	}

	if ($text !~ /\</) {
		return $text;
	}

	my $xml = new XML::Simple;
	my $doc = $xml->xml_in($text);

	if (ref $doc->{'display_location'}->{'latitude'} eq 'HASH') {
		return 'No weather information available for ' . $station;
	}

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
		'6|Relative humidity' => 'relative_humidity',
		'7|Pressure'          => 'pressure_string',
		'8|Winds'             => 'wind_string',
		'9|Visibility'        => 'visibility_mi| mile(s)'
	);

	my $weather = "Current conditions for $doc->{'display_location'}->{'full'} ($doc->{'station_id'}). $doc->{'observation_time'}. ";

	foreach my $text (sort { $a cmp $b } keys %components) {
		my $ref    = $components{ $text };
		my $append = '';
		$text      =~ s/\d+\|//;
		if ($ref =~ /(.+)\|(.+)/) {
			$ref = $1;
			$append = $2;
		}
		my $value = $doc->{ $ref };
		# Skip missing data
		if (ref($value) || $value eq 'NA' || $value eq 'N/A%' || $value eq '-9999' || $value eq '-9999 F (-9999 C)' || $value eq ' in ( mb)' || $value eq ' F ( C)') {
			next;
		}

		if ($value) {
			$weather .= sprintf("%s: %s%s. ", $text, $value, $append);
		}
	}

	my %info = (
		'retrieved' => time(),
		'weather'   => $weather
	);
	$cache{ $station } = \%info;
	return $weather;
}

sub help($)
{
	my $message = shift;

	return "Usage: weather <location>\nReturns a formatted string with the latest weather observation for the given location (airport code, ZIP code, etc.).";
}

1;
