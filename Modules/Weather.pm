package Modules::Weather;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use JSON;
use LWP::Simple;
use URI::Escape qw/ uri_escape /;

#######
## GLOBALS
#######
my $CACHE_TIME = 15;	# time to cache (in minutes)

use constant URL_FORMAT => 'http://api.wunderground.com/api/%s/conditions/q/%s.json'; # 1: API key, 2: location

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

	my $moduleConfig = $Bot::config->{'modules'}->{'Weather'};

	if (not defined $moduleConfig) {
		Bot::status("Modules::Weather: no configuration information present; skipping initialization");
		return -1;
	}

	unless ($moduleConfig->{'api_key'}) {
		Bot::status("Modules::Weather: no 'api_key' configuration value provided; skipping initialization");
		return -1;
	}

	Modules::register_action('weather', \&Modules::Weather::process);
	Modules::register_help('weather', \&Modules::Weather::help);
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

	Bot::debug("Looking up weather for '%s'", $station);

	my $text = get(sprintf(URL_FORMAT, $Bot::config->{'modules'}->{'Weather'}->{'api_key'}, uri_escape($station)));

	unless ($text) {
		return 'Something failed in contacting the weather server.';
	}

  my $data = from_json($text);

	if ($data->{'response'}->{'error'}) {
		return "Unable to get weather for ${station}: $data->{'response'}->{'error'}->{'description'}";
	}

	$data = $data->{'current_observation'};

	if (ref $data->{'display_location'}->{'latitude'} eq 'HASH' || ref $data->{'observation_location'}->{'latitude'} eq 'HASH') {
		return 'No weather information available for ' . $station;
	}

  my @components = (
    { 'field' => 'weather',            'label' => 'Sky conditions' },
    { 'field' => 'temperature_string', 'label' => 'Temperature' },
    { 'field' => 'dewpoint_string',    'label' => 'Dewpoint' },
    { 'field' => 'heat_index_string',  'label' => 'Heat index' },
    { 'field' => 'windchill_string',   'label' => 'Wind chill' },
    { 'field' => 'relative_humidity',  'label' => 'Relative humidity' },
    { 'field' => 'pressure_string',    'label' => 'Pressure' },
    { 'field' => 'wind_string',        'label' => 'Winds' },
    { 'field' => 'visibility_mi',      'label' => 'Visibility', 'append' => ' mile(s)' },
  );

	my $weather = "Current conditions for $data->{'display_location'}->{'full'} ($data->{'station_id'}). $data->{'observation_time'}. ";

  foreach my $component (@components) {
    my $field        = $component->{'field'};
    my $label        = $component->{'label'};
    my $textToAppend = $component->{'append'} || '';

		my $value = $data->{ $field };
		# Skip missing data
		if (ref($value) || $value eq 'NA' || $value eq 'N/A' || $value eq 'N/A%' || $value eq '-9999' || $value eq '-9999 F (-9999 C)' || $value eq ' in ( mb)' || $value eq ' F ( C)' || $value eq '-9999.00 in (-9999 mb)') {
			next;
		}

		if ($value) {
			$weather .= sprintf("%s: %s%s. ", $label, $value, $textToAppend);
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
