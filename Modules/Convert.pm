package Modules::Convert;

#######
## NOTES
## The following conversions are provided:
## * TEMPERATURE
##   * Celcius to Fahrenheit
##   * Celcius to Kelvin
##   * Fahrenheit to Celcius
##   * Fahrenheit to Kelvin
##   * Kelvin to Fahrenheit
##   * Kelvin to Celcius

## * DISTANCE
##   * Centimeters to inches
##   * Centimeters to feet
##   * Centimeters to kilometers
##   * Centimeters to meters
##   * Centimeters to nautical miles
##   * Centimeters to (statute) miles
##   * Centimeters to yards
##
##   * Feet to centimeters
##   * Feet to inches
##   * Feet to kilometers
##   * Feet to meters
##   * Feet to nautical miles
##   * Feet to (statute) miles
##   * Feet to yards
##
##   * Inches to centimeters
##   * Inches to feet
##   * Inches to kilometers
##   * Inches to meters
##   * Inches to nautical miles
##   * Inches to (statute) miles
##   * Inches to yards
##
##   * Meters to centimeters
##   * Meters to feet
##   * Meters to inches
##   * Meters to kilometers
##   * Meters to nautical miles
##   * Meters to (statute) miles
##   * Meters to yards
##
##   * Nautical miles to centimeters
##   * Nautical miles to feet
##   * Nautical miles to inches
##   * Nautical miles to kilometers
##   * Nautical miles to meters
##   * Nautical miles to (statute) miles
##   * Nautical miles to yards
##
##   * (Statute) Miles to centimeters
##   * (Statute) Miles to feet
##   * (Statute) Miles to inches
##   * (Statute) Miles to kilometers
##   * (Statute) Miles to meters
##   * (Statute) Miles to nautical miles
##   * (Statute) Miles to yards
##
##   * Yards to centimeters
##   * Yards to feet
##   * Yards to inches
##   * Yards to kilometers
##   * Yards to meters
##   * Yards to nautical miles
##   * Yards to (statute) miles

## * Speed
##   * miles/hour
##   * miles/minute
##   * miles/second
##   * feet/hour
##   * feet/minute
##   * feet/second
##   * km/hour
##   * km/minute
##   * km/second
##   * m/hour
##   * m/minute
##   * m/second
#######
## PERL SETUP
#######
use strict;

my %aliases;
my %conversions;

my $match_expr = qr/^\s*convert\s+(\d*(\.\d+)?)\s*(.+)\s+to\s+(.+)\s*$/;

##############
sub new()
{
	my $pkg = shift;
	my $obj = {	};
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	# Initialize conversions
	%aliases = (
		'celcius'     => 'c',
		'centigrade'  => 'c',
		'centimeter'  => 'cm',
		'centimeters' => 'cm',
		'centimetre'  => 'cm',
		'centimetres' => 'cm',
		'fahrenheit'  => 'f',
		'feet'        => 'ft',
		'foot'        => 'ft',
		'fps'         => 'ft/s',
		'hour'        => 'hr',
		'hours'       => 'hr',
		'inch'        => 'in',
		'inches'      => 'in',
		'kelvin'      => 'k',
		'k'           => 'km',
		'kilometer'   => 'km',
		'kilometers'  => 'km',
		'kilometre'   => 'km',
		'kilometres'  => 'km',
		'meter'       => 'm',
		'meters'      => 'm',
		'metre'       => 'm',
		'metres'      => 'm',
		'mile'        => 'mi',
		'miles'       => 'mi',
		'minute'      => 'min',
		'minutes'     => 'min',
		'mph'         => 'mi/hr',
		'second'      => 's',
		'seconds'     => 's',
		'sm'          => 'mi',
		'yard'        => 'yd',
		'yards'       => 'yd'
	);

	%conversions = (
		## Temperature conversions
		'c|f'    => \&celcius_to_fahrenheit,
		'c|k'    => \&celcius_to_kelvin,
		'f|c'    => \&fahrenheit_to_celcius,
		'f|k'    => \&fahrenheit_to_kelvin,
		'k|c'    => \&kelvin_to_celcius,
		'k|f'    => \&kelvin_to_fahrenheit,

		## Distance conversions
		'cm|ft'  => \&centimeters_to_feet,
		'cm|in'  => \&centimeters_to_inches,
		'cm|km'  => \&centimeters_to_kilometers,
		'cm|m'   => \&centimeters_to_meters,
		'cm|nm'  => \&centimeters_to_nautical_miles,
		'cm|mi'  => \&centimeters_to_miles,
		'cm|yd'  => \&centimeters_to_yards,
		'ft|cm'  => \&feet_to_centimeters,
		'ft|in'  => \&feet_to_inches,
		'ft|km'  => \&feet_to_kilometers,
		'ft|m'   => \&feet_to_meters,
		'ft|nm'  => \&feet_to_nautical_miles,
		'ft|mi'  => \&feet_to_miles,
		'ft|yd'  => \&feet_to_yards,
		'in|cm'  => \&inches_to_centimeters,
		'in|ft'  => \&inches_to_feet,
		'in|km'  => \&inches_to_kilometers,
		'in|m'   => \&inches_to_meters,
		'in|nm'  => \&inches_to_nautical_miles,
		'in|mi'  => \&inches_to_miles,
		'in|yd'  => \&inches_to_yards,
		'km|cm'  => \&kilometers_to_centimeters,
		'km|ft'  => \&kilometers_to_feet,
		'km|in'  => \&kilometers_to_inches,
		'km|m'   => \&kilometers_to_meters,
		'km|nm'  => \&kilometers_to_nautical_miles,
		'km|mi'  => \&kilometers_to_miles,
		'km|yd'  => \&kilometers_to_yards,
		'm|cm'   => \&meters_to_centimeters,
		'm|ft'   => \&meters_to_feet,
		'm|in'   => \&meters_to_inches,
		'm|km'   => \&meters_to_kilometers,
		'm|nm'   => \&meters_to_nautical_miles,
		'm|mi'   => \&meters_to_miles,
		'm|yd'   => \&meters_to_yards,
		'nm|cm'  => \&nautical_miles_to_centimeters,
		'nm|ft'  => \&nautical_miles_to_feet,
		'nm|in'  => \&nautical_miles_to_inches,
		'nm|km'  => \&nautical_miles_to_kilometers,
		'nm|m'   => \&nautical_miles_to_meters,
		'nm|mi'  => \&nautical_miles_to_miles,
		'nm|yd'  => \&nautical_miles_to_yards,
		'mi|cm'  => \&miles_to_centimeters,
		'mi|ft'  => \&miles_to_feet,
		'mi|in'  => \&miles_to_inches,
		'mi|km'  => \&miles_to_kilometers,
		'mi|m'   => \&miles_to_meters,
		'mi|nm'  => \&miles_to_nautical_miles,
		'mi|yd'  => \&miles_to_yards,
		'yd|cm'  => \&yards_to_centimeters,
		'yd|ft'  => \&yards_to_feet,
		'yd|in'  => \&yards_to_inches,
		'yd|km'  => \&yards_to_kilometers,
		'yd|m'   => \&yards_to_meters,
		'yd|mi'  => \&yards_to_miles,
		'yd|nm'  => \&yards_to_nautical_miles,

		# Time conversions
		'hr|min' => \&hours_to_minutes,
		'hr|s'   => \&hours_to_seconds,
		'min|hr' => \&minutes_to_hours,
		'min|s'  => \&minutes_to_seconds,
		's|hr'   => \&seconds_to_hours,
		's|min'  => \&seconds_to_minutes
	);	

	&Modules::register_action($match_expr, \&Modules::Convert::process);
}

sub process($)
{
	my $message = shift;

	my ($value, $from, $to);

	if ($message->message() =~ $match_expr) {
		$value = $1;
		$from  = lc($3);
		$to    = lc($4);

		my $f  = $aliases{ $from } || $from;
		my $t  = $aliases{ $to } || $to;

		if ($f =~ m|/|) {
			# Compound unit
			my ($from_unit, $from_per) = split(/\//, $f, 2);
			my ($to_unit, $to_per) = split(/\//, $t, 2);

			unless ($to_per) {
				if ($message->is_addressed()) {
					return "I can't convert $from to $to!";
				}
				return;
			}

			# When converting the units in the denominator, reverse the direction of the conversion.
			# This is to account for the fact that it _is_ in the denominator.

			my $result;
			if ($from_unit eq $to_unit && $conversions{"$to_per|$from_per"}) {
				$result = $conversions{"$to_per|$from_per"}->($value);
			} elsif ($from_per eq $to_per && $conversions{"$from_unit|$to_unit"}) {
				$result = $conversions{"$from_unit|$to_unit"}->($value);
			} elsif ($conversions{"$from_unit|$to_unit"} && $conversions{"$to_per|$from_per"}) {
				$result = $conversions{"$to_per|$from_per"}->($conversions{"$from_unit|$to_unit"}->($value));
			} elsif ($message->is_addressed()) {
				return "I don't know how to convert between $from and $to!";
			}
			if ($result) {
				return sprintf("%.2f %s is %.2f %s", $value, $from, $result, $to);
			}

		} else {
			if ($conversions{"$f|$t"}) {
				my $result = $conversions{"$f|$t"}->($value);
				return sprintf("%.2f %s is %.2f %s", $value, $from, $result, $to);
			} elsif ($message->is_addressed()) {
				return "I don't know how to convert between $from and $to!";
			}
		}
	}
}

#######
## TEMPERATURE CONVERSIONS
#######
sub celcius_to_fahrenheit($)
{
	my $temp = shift;

	return ((9.0 * $temp) / 5.0) + 32;
}

sub celcius_to_kelvin($)
{
	my $temp = shift;

	return $temp + 273.15;
}

sub fahrenheit_to_celcius($)
{
	my $temp = shift;

	return (5.0 * ($temp - 32)) / 9.0;
}

sub fahrenheit_to_kelvin($)
{
	my $temp = shift;

	return &celcius_to_kelvin(&fahrenheit_to_celcius($temp));
}

sub kelvin_to_celcius($)
{
	my $temp = shift;

	return $temp - 273.15;
}

sub kelvin_to_fahrenheit($)
{
	my $temp = shift;

	return &celcius_to_fahrenheit(&kelvin_to_celcius($temp));
}

#######
## DISTANCE CONVERSIONS
## (UNITS: Centimeters, Feet, Inches, Kilometers, Meters, Nautical Miles, (Statute) Miles, Yards)
#######
sub centimeters_to_feet($)
{
	my $dist = shift;

	return &inches_to_feet(&centimeters_to_inches($dist));
}

sub centimeters_to_inches($)
{
	my $dist = shift;

	return $dist * 0.393700787;
}

sub centimeters_to_kilometers($)
{
	my $dist = shift;

	return &meters_to_kilometers(&centimeters_to_meters($dist));
}

sub centimeters_to_meters($)
{
	my $dist = shift;

	return $dist / 1000;
}

sub centimeters_to_nautical_miles($)
{
	my $dist = shift;

	return &meters_to_nautical_miles(&centimeters_to_meters($dist));
}

sub centimeters_to_miles($)
{
	my $dist = shift;

	return &feet_to_miles(&centimeters_to_feet($dist));
}

sub centimeters_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&centimeters_to_feet($dist));
}

sub feet_to_centimeters($)
{
	my $dist = shift;

	return &inches_to_centimeters(&feet_to_inches($dist));
}

sub feet_to_inches($)
{
	my $dist = shift;

	return $dist * 12;
}

sub feet_to_kilometers($)
{
	my $dist = shift;

	return &meters_to_kilometers(&feet_to_meters($dist));
}

sub feet_to_meters($)
{
	my $dist = shift;

	return &centimeters_to_meters(&feet_to_centimeters($dist));
}

sub feet_to_miles($)
{
	my $dist = shift;

	return $dist / 5280;
}

sub feet_to_nautical_miles($)
{
	my $dist = shift;

	return &miles_to_nautical_miles(&feet_to_miles($dist));
}

sub feet_to_yards($)
{
	my $dist = shift;

	return $dist / 3;
}

sub inches_to_centimeters($)
{
	my $dist = shift;

	return $dist / 0.393700787;
}

sub inches_to_feet($)
{
	my $dist = shift;

	return $dist / 12;
}

sub inches_to_kilometers($)
{
	my $dist = shift;

	return &meters_to_kilometers(&inches_to_meters($dist));
}

sub inches_to_meters($)
{
	my $dist = shift;

	return &centimeters_to_meters(&inches_to_centimeters($dist));
}

sub inches_to_miles($)
{
	my $dist = shift;

	return &feet_to_miles(&inches_to_feet($dist));
}

sub inches_to_nautical_miles($)
{
	my $dist = shift;

	return &feet_to_nautical_miles(&inches_to_feet($dist));
}

sub inches_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&inches_to_feet($dist));
}

sub kilometers_to_centimeters($)
{
	my $dist = shift;

	return &meters_to_centimeters(&kilometers_to_meters($dist));
}

sub kilometers_to_feet($)
{
	my $dist = shift;

	return &meters_to_feet(&kilometers_to_meters($dist));
}

sub kilometers_to_inches($)
{
	my $dist = shift;

	return &feet_to_inches(&kilometers_to_feet($dist));
}

sub kilometers_to_meters($)
{
	my $dist = shift;

	return $dist * 1000;
}

sub kilometers_to_miles($)
{
	my $dist = shift;

	return $dist * 0.621371192;
}

sub kilometers_to_nautical_miles($)
{
	my $dist = shift;

	return &miles_to_nautical_miles(&kilometers_to_miles($dist));
}

sub kilometers_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&kilometers_to_feet($dist));
}

sub meters_to_centimeters($)
{
	my $dist = shift;

	return $dist * 1000;
}

sub meters_to_feet($)
{
	my $dist = shift;

	return $dist * 3.2808399;
}

sub meters_to_inches($)
{
	my $dist = shift;

	return &feet_to_inches(&meters_to_feet($dist));
}

sub meters_to_kilometers($)
{
	my $dist = shift;

	return $dist / 1000;
}

sub meters_to_miles($)
{
	my $dist = shift;

	return &feet_to_miles(&meters_to_feet($dist));
}

sub meters_to_nautical_miles($)
{
	my $dist = shift;

	return &feet_to_nautical_miles(&meters_to_feet($dist));
}

sub meters_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&meters_to_feet($dist));
}

sub miles_to_centimeters($)
{
	my $dist = shift;

	return &kilometers_to_centimeters(&miles_to_kilometers($dist));
}

sub miles_to_feet($)
{
	my $dist = shift;

	return $dist * 5280;
}

sub miles_to_inches($)
{
	my $dist = shift;

	return &feet_to_inches(&miles_to_feet($dist));
}

sub miles_to_kilometers($)
{
	my $dist = shift;

	return $dist / 0.621371192;
}

sub miles_to_meters($)
{
	my $dist = shift;

	return &kilometers_to_meters(&miles_to_kilometers($dist));
}

sub miles_to_nautical_miles($)
{
	my $dist = shift;

	return $dist * 0.868976242;
}

sub miles_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&miles_to_feet($dist));
}

sub nautical_miles_to_centimeters($)
{
	my $dist = shift;

	return &miles_to_centimeters(&nautical_miles_to_miles($dist));
}

sub nautical_miles_to_feet($)
{
	my $dist = shift;

	return &miles_to_feet(&nautical_miles_to_miles($dist));
}

sub nautical_miles_to_inches($)
{
	my $dist = shift;

	return &feet_to_inches(&nautical_miles_to_feet($dist));
}

sub nautical_miles_to_kilometers($)
{
	my $dist = shift;

	return &miles_to_kilometers(&nautical_miles_to_miles($dist));
}

sub nautical_miles_to_meters($)
{
	my $dist = shift;

	return &kilometers_to_meters(&nautical_miles_to_kilometers($dist));
}

sub nautical_miles_to_miles($)
{
	my $dist = shift;

	return $dist / 0.868976242;
}

sub nautical_miles_to_yards($)
{
	my $dist = shift;

	return &feet_to_yards(&nautical_miles_to_feet($dist));
}

sub yards_to_centimeters($)
{
	my $dist = shift;

	return &feet_to_centimeters(&yards_to_feet($dist));
}

sub yards_to_feet($)
{
	my $dist = shift;

	return $dist * 3;
}

sub yards_to_inches($)
{
	my $dist = shift;

	return &feet_to_inches(&yards_to_feet($dist));
}

sub yards_to_kilometers($)
{
	my $dist = shift;

	return &meters_to_kilometers(&yards_to_meters($dist));
}

sub yards_to_miles($)
{
	my $dist = shift;

	return &feet_to_miles(&yards_to_feet($dist));
}

sub yards_to_nautical_miles($)
{
	my $dist = shift;

	return &miles_to_nautical_miles(&yards_to_miles($dist));
}

#######
## TIME CONVERSIONS
## (UNITS: Hours, Minutes, Seconds)
#######
sub hours_to_minutes($)
{
	my $hours = shift;

	return $hours * 60;
}

sub hours_to_seconds($)
{
	my $hours = shift;

	return &minutes_to_seconds(&hours_to_minutes($hours));
}

sub minutes_to_hours($)
{
	my $minutes = shift;

	return $minutes / 60;
}

sub minutes_to_seconds($)
{
	my $minutes = shift;

	return $minutes * 60;
}

sub seconds_to_hours($)
{
	my $seconds = shift;

	return &minutes_to_hours(&seconds_to_minutes($seconds));
}

sub seconds_to_minutes($)
{
	my $seconds = shift;

	return $seconds / 60;
}

1;
