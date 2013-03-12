package Modules::Weather;

use strict;

use GIR::Util;

use JSON;
use URI::Escape qw/ uri_escape /;

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

	my $moduleConfig = $GIR::Bot::config->{'modules'}->{'Weather'};

	if (not defined $moduleConfig) {
		GIR::Bot::status("Modules::Weather: no configuration information present; skipping initialization");
		return -1;
	}

	unless ($moduleConfig->{'api_key'}) {
		GIR::Bot::status("Modules::Weather: no 'api_key' configuration value provided; skipping initialization");
		return -1;
	}

	GIR::Modules::register_action('weather', \&Modules::Weather::process);
	GIR::Modules::register_help('weather', \&Modules::Weather::help);
}

sub process($)
{
	my $message = shift;

	my $location = $message->message();

	return unless $location;

	# Check if we have cached data, and it's still valid
	if ($cache{ $location } && $cache{ $location }->{'retrieved'} + ($CACHE_TIME * 60) > time()) {
		return $cache{ $location }->{'weather'};
	}

	GIR::Bot::debug("Modules::Weather: Looking up weather for '%s'", $location);

	my $url = sprintf(URL_FORMAT, $GIR::Bot::config->{'modules'}->{'Weather'}->{'api_key'}, uri_escape($location));
	my $content = eval { get_url($url) };

	if ($@) {
		GIR::Bot::error('Modules::Weather: request to server failed: %s', $@);
		return $message->is_explicit ? 'Something failed in contacting the weather server.' : undef;
	}

  my $data = from_json($content);

	if ($data->{'response'}->{'error'}) {
		GIR::Bot::debug('Modules::Weather: weather server returned an error: %s', $data->{'response'}->{'error'}->{'description'});
		return $message->is_explicit ? "Unable to get weather for ${location}: $data->{'response'}->{'error'}->{'description'}" : undef;
	}

	unless (exists $data->{'current_observation'}) {
		GIR::Bot::debug("Modules::Weather: no current conditions found for '%s'; location may be ambiguous", $location);
		return $message->is_explicit ? "No weather information available for ${location}" : undef;
	}

	$data = $data->{'current_observation'};

	if (ref $data->{'display_location'}->{'latitude'} eq 'HASH' || ref $data->{'observation_location'}->{'latitude'} eq 'HASH') {
		return $message->is_explicit ? "No weather information available for ${location}" : undef;
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
	$cache{ $location } = \%info;
	return $weather;
}

sub help($)
{
	my $message = shift;

	return "Usage: weather <location>\nReturns a formatted string with the latest weather observation for the given location (airport code, ZIP code, etc.).";
}

1;
