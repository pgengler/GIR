package Modules::Weather;

use strict;
use utf8;

use JSON;
use URI::Escape qw/ uri_escape /;

my $CACHE_TIME = 15;	# time to cache (in minutes)

use constant URL_FORMAT => 'http://api.wunderground.com/api/%s/conditions/q/%s.json'; # 1: API key, 2: location

my %cache;

sub register
{
	unless (config('api_key')) {
		GIR::Bot::status("Modules::Weather: no 'api_key' configuration value provided; skipping initialization");
		return -1;
	}

	GIR::Modules::register_action('weather', \&Modules::Weather::process);
	GIR::Modules::register_help('weather', \&Modules::Weather::help);
}

sub process
{
	my $message = shift;

	my $location = $message->message;

	return unless $location;

	# Check if we have cached data, and it's still valid
	if ($cache{ $location } && $cache{ $location }->{'retrieved'} + ($CACHE_TIME * 60) > time) {
		return $cache{ $location }->{'weather'};
	}

	GIR::Bot::debug("Modules::Weather: Looking up weather for '%s'", $location);

	my $url = sprintf(URL_FORMAT, config('api_key'), uri_escape(uc($location)));
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

	# Preprocess data

	if (is_valid($data->{'visibility_mi'})) {
		$data->{'visibility_string'} = "$data->{'visibility_mi'} mi ($data->{'visibility_km'} km)";
	}

	if (is_valid($data->{'pressure_mb'})) {
		$data->{'pressure_string'} = "$data->{'pressure_in'} in ($data->{'pressure_mb'} mb) ($data->{'pressure_trend'})";
	}

	# Build output string
	my @components = (
		{ 'field' => 'windchill_string',   'label' => 'Wind chill', 'process' => \&format_temperature },
		{ 'field' => 'heat_index_string',  'label' => 'Heat index', 'process' => \&format_temperature },
		{ 'field' => 'wind_string',        'label' => 'Winds' },
		{ 'field' => 'dewpoint_string',    'label' => 'Dewpoint',   'process' => \&format_temperature },
		{ 'field' => 'relative_humidity',  'label' => 'Relative humidity' },
		{ 'field' => 'pressure_string',    'label' => 'Pressure' },
		{ 'field' => 'visibility_string',  'label' => 'Visibility' },
		{ 'field' => 'station_id',         'label' => 'Station' },
		{ 'field' => 'observation_time',   'label' => 'Updated',    'process' => sub { $_[0] =~ s/Last Updated on //; $_[0] } },
	);

	my $temperature = format_temperature($data->{'temperature_string'});
	my $weather = "$data->{'display_location'}->{'full'}: $data->{'weather'}, ${temperature}. ";

	foreach my $component (@components) {
		my $field        = $component->{'field'};
		my $label        = $component->{'label'};
		my $textToAppend = $component->{'append'} || '';

		my $value = $data->{ $field };
		# Skip missing data
		next unless is_valid($value);

		if (exists $component->{'process'}) {
			$value = $component->{'process'}->($value);
		}

		if ($value) {
			$weather .= sprintf("%s: %s%s. ", $label, $value, $textToAppend);
		}
	}

	my %info = (
		'retrieved' => time,
		'weather'   => $weather
	);
	$cache{ $location } = \%info;
	return $weather;
}

sub help
{
	my $message = shift;

	return "Usage: weather <location>\nReturns a formatted string with the latest weather observation for the given location (airport code, ZIP code, etc.).";
}

##############
sub is_valid
{
	my ($value) = @_;

	if (ref($value) || $value eq 'NA' || $value eq 'N/A' || $value eq 'N/A%' || $value eq '-9999' || $value eq '-9999 F (-9999 C)' || $value eq ' in ( mb)' || $value eq ' F ( C)' || $value eq '-9999.00 in (-9999 mb)' || $value eq '') {
		return 0;
	}
	return 1;
}

sub format_temperature
{
	my ($value) = @_;

	$value =~ s/ (C|F)/°$1/g;

	return $value;
}

1;
