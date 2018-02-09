package Modules::Convert;

use strict;

use Graph;

my %aliases;

my $match_expr = qr/^\s*convert\s+([+-]?\d*(\.\d+)?)\s*(.+)\s+to\s+(.+)\s*$/;

my $conversions = {
	# distance conversions
	'au' => {
		'km' => \&astronomical_units_to_kilometers,
	},
	'cm' => {
		'in' => \&centimeters_to_inches,
		'm'  => metric_decrease_magnitude(2),
		'mm' => metric_increase_magnitude(1),
	},
	'ft' => {
		'in' => \&feet_to_inches,
		'mi' => \&feet_to_miles,
		'yd' => \&feet_to_yards,
	},
	'in' => {
		'cm' => \&inches_to_centimeters,
		'ft' => \&inches_to_feet,
	},
	'km' => {
		'au' => \&kilometers_to_astronomical_units,
		'ly' => \&kilometers_to_light_years,
		'm'  => metric_increase_magnitude(3),
	},
	'ls' => {
		'ly' => \&light_seconds_to_light_years,
	},
	'ly' => {
		'ls' => \&light_years_to_light_seconds,
		'km' => \&light_years_to_kilometers,
		'pc' => \&light_years_to_parsecs,
	},
	'm'  => {
		'cm' => metric_increase_magnitude(2),
		'km' => metric_decrease_magnitude(3),
	},
	'mi' => {
		'ft' => \&miles_to_feet,
		'nm' => \&miles_to_nautical_miles,
	},
	'mm' => {
		'cm' => metric_decrease_magnitude(1),
	},
	'nm' => {
		'mi' => \&nautical_miles_to_miles,
	},
	'pc' => {
		'ly' => \&parsecs_to_light_years,
	},
	'yd' => {
		'ft' => \&yards_to_feet,
	},

	# temperature conversions
	'c' => {
		'f' => \&celcius_to_fahrenheit,
		'k' => \&celcius_to_kelvin,
	},
	'f' => {
		'c' => \&fahrenheit_to_celcius,
	},
	'k' => {
		'c' => \&kelvin_to_celcius,
	},

	# time conversions
	'hr'  => {
		'min' => \&hours_to_minutes,
	},
	'min' => {
		'hr'  => \&minutes_to_hours,
		's'   => \&minutes_to_seconds,
	},
	's'   => {
		'min' => \&seconds_to_minutes,
	},

	# weight/mass conversions
	'g' => {
		'kg' => metric_decrease_magnitude(3),
	},
	'kg' => {
		'lb' => \&kilograms_to_pounds,
		'g'  => metric_increase_magnitude(3),
	},
	'lb' => {
		'kg' => \&pounds_to_kilograms,
		'oz' => \&pounds_to_ounces,
		'st' => \&pounds_to_stone,
	},
	'oz' => {
		'lb' => \&ounces_to_pounds,
	},
	'st' => {
		'lb' => \&stone_to_pounds,
	},

	# volume conversions
	'gal' => {
		'l' => \&gallons_to_liters,
	},
	'l' => {
		'gal' => \&liters_to_gallons,
		'ml'  => metric_increase_magnitude(3),
	},
	'ml' => {
		'l' => metric_decrease_magnitude(3),
	},

	# pressure conversions
	'atm' => {
		'bar' => \&atmospheres_to_bars,
		'pa'  => \&atmospheres_to_pascals,
		'psi' => \&atmospheres_to_psi,
	},
	'bar' => {
		'atm' => \&bars_to_atmospheres,
		'mbar' => metric_increase_magnitude(3),
		'pa'  => metric_increase_magnitude(5),
		'psi' => \&bars_to_psi,
	},
	'mbar' => {
		'bar' => metric_decrease_magnitude(3),
	},
	'hpa' => {
		'pa' => metric_increase_magnitude(2),
	},
	'kpa' => {
		'pa' => metric_decrease_magnitude(3),
	},
	'mpa' => {
		'pa' => metric_decrease_magnitude(6),
	},
	'pa' => {
		'atm' => \&pascals_to_atmospheres,
		'bar' => metric_decrease_magnitude(5),
		'hpa' => metric_decrease_magnitude(2),
		'kpa' => metric_increase_magnitude(3),
		'mpa' => metric_increase_magnitude(6),
		'psi' => \&pascals_to_psi,
	},
	'psi' => {
		'atm' => \&psi_to_atmospheres,
		'bar' => \&psi_to_bars,
		'pa'  => \&psi_to_pascals,
	},

	# bytes and such
	'bits' => {
		'bytes' => \&bits_to_bytes,
	},
	'bytes' => {
		'bits' => \&bytes_to_bits,
		'kb'  => \&byte_order_of_magnitude_up,
	},
	'kb' => {
		'bytes' => \&byte_order_of_magnitude_down,
		'mb'    => \&byte_order_of_magnitude_up,
	},
	'mb' => {
		'gb' => \&byte_order_of_magnitude_up,
		'kb' => \&byte_order_of_magnitude_down,
	},
	'gb' => {
		'tb' => \&byte_order_of_magnitude_up,
		'mb' => \&byte_order_of_magnitude_down,
	},
	'tb' => {
		'gb' => \&byte_order_of_magnitude_down,
		'pb' => \&byte_order_of_magnitude_up,
	},
	'pb' => {
		'tb' => \&byte_order_of_magnitude_down,
	},
};

##############
sub register
{
	# Initialize conversions
	%aliases = (
		'atmosphere'    => 'atm',
		'atmospheres'   => 'atm',
		'bit'           => 'bits',
		'byte'          => 'bytes',
		'celcius'       => 'c',
		'centigrade'    => 'c',
		'centimeter'    => 'cm',
		'centimeters'   => 'cm',
		'centimetre'    => 'cm',
		'centimetres'   => 'cm',
		'fahrenheit'    => 'f',
		'feet'          => 'ft',
		'foot'          => 'ft',
		'fps'           => 'ft/s',
		'gallon'        => 'gal',
		'gallons'       => 'gal',
		'gigabyte'      => 'gb',
		'gigabytes'     => 'gb',
		'gram'          => 'g',
		'grams'         => 'g',
		'h'             => 'hr',
		'hectopascal'   => 'hpa',
		'hectopascals'  => 'hpa',
		'hour'          => 'hr',
		'hours'         => 'hr',
		'inch'          => 'in',
		'inches'        => 'in',
		'kelvin'        => 'k',
		'kilobyte '     => 'kb',
		'kilobytes'     => 'kb',
		'kilogram'      => 'kg',
		'kilograms'     => 'kg',
		'kilometer'     => 'km',
		'kilometers'    => 'km',
		'kilometre'     => 'km',
		'kilometres'    => 'km',
		'kilopascal'    => 'kpa',
		'kilopascals'   => 'kpa',
		'knot'          => 'nm/hr',
		'knots'         => 'nm/hr',
		'kph'           => 'km/hr',
		'kt'            => 'nm/hr',
		'lb/in2'        => 'psi',
		'lb/square in'  => 'psi',
		'lb/sq.in'      => 'psi',
		'lb/sq. in'     => 'psi',
		'lb/sqin'       => 'psi',
		'lbs'           => 'lb',
		'light-second'  => 'ls',
		'light second'  => 'ls',
		'light-seconds' => 'ls',
		'light seconds' => 'ls',
		'light-year'    => 'ly',
		'light year'    => 'ly',
		'light-years'   => 'ly',
		'light years'   => 'ly',
		'lightyear'     => 'ly',
		'lightyears'    => 'ly',
		'liter'         => 'l',
		'liters'        => 'l',
		'litre'         => 'l',
		'litres'        => 'l',
		'megabyte'      => 'mb',
		'megabytes'     => 'mb',
		'megapascal'    => 'mpa',
		'megapascals'   => 'mpa',
		'meter'         => 'm',
		'meters'        => 'm',
		'metre'         => 'm',
		'metres'        => 'm',
		'mile'          => 'mi',
		'miles'         => 'mi',
		'milliliter'    => 'ml',
		'milliliters'   => 'ml',
		'millilitre'    => 'ml',
		'millilitres'   => 'ml',
		'minute'        => 'min',
		'minutes'       => 'min',
		'mph'           => 'mi/hr',
		'ounce'         => 'oz',
		'ounces'        => 'oz',
		'parsec'        => 'pc',
		'parsecs'       => 'pc',
		'petabyte'      => 'pb',
		'petabytes'     => 'pb',
		'pound'         => 'lb',
		'pounds'        => 'lb',
		'second'        => 's',
		'seconds'       => 's',
		'sm'            => 'mi',
		'stone'         => 'st',
		'stones'        => 'st',
		'terabyte'      => 'tb',
		'terabytes'     => 'tb',
		'ua'            => 'au',
		'yard'          => 'yd',
		'yards'         => 'yd'
	);

	GIR::Modules->register_action($match_expr, \&Modules::Convert::process);
}

sub process
{
	my $message = shift;

	if ($message->message =~ $match_expr) {
		my $value    = $1 || 1;
		my $fromUnit = lc($3);
		my $toUnit   = lc($4);

		$fromUnit = $aliases{ $fromUnit } || $fromUnit;
		$toUnit   = $aliases{ $toUnit }   || $toUnit;

		my $converted;

		if ($fromUnit =~ m|/|) {
			# compound unit
			my ($fromPer, $toPer);
			($fromUnit, $fromPer) = split(/\//, $fromUnit, 2);
			($toUnit,   $toPer)   = split(/\//, $toUnit,   2);

			$fromUnit = $aliases{ $fromUnit } || $fromUnit;
			$toUnit   = $aliases{ $toUnit }   || $toUnit;
			$fromPer  = $aliases{ $fromPer }  || $fromPer;
			$toPer    = $aliases{ $toPer }    || $toPer;

			if ($fromUnit eq $toUnit) {
				# same unit in numerator
				# switch the direction of the conversion to account for the fact that now we're converting from the denominator
				$converted = _convert($value, $toPer, $fromPer);
			} elsif ($fromPer eq $toPer) {
				# same unit in denominator
				$converted = _convert($value, $fromUnit, $toUnit);
			} else {
				# different units in numerator and denominator
				$converted = _convert(_convert($value, $fromUnit, $toUnit), $toPer, $fromPer);
			}

			# reassemble $fromUnit and $toUnit into complex unit for display
			$fromUnit = sprintf('%s/%s', $fromUnit, $fromPer);
			$toUnit   = sprintf('%s/%s', $toUnit,   $toPer);

		} else {
			$converted = _convert($value, $fromUnit, $toUnit);
		}

		if (defined $converted) {
			return sprintf('%s %s is %s %s', $value, $fromUnit, $converted, $toUnit);
		} else {
			return sprintf("Can't convert between '%s' and '%s'!", $fromUnit, $toUnit);
		}
	}
}

sub _convert
{
	my ($value, $fromUnit, $toUnit) = @_;

	my $graph = _buildGraph();

	my @path = $graph->SP_Dijkstra($fromUnit, $toUnit);

	my $converted;
	if (scalar(@path) == 1) {
		$converted = $value;
	} elsif (scalar(@path) > 1) {
		$converted = $value;

		my $from = $path[0];
		foreach my $i (1..$#path) {
			my $to = $path[$i];

			$converted = $conversions->{ $from }->{ $to }->($converted);

			$from = $to;
		}
	}

	return $converted;
}

sub _buildGraph
{
	my $graph = Graph->new;

	foreach my $from (keys %$conversions) {
		foreach my $to (keys %{ $conversions->{ $from } }) {
			$graph->add_edge($from, $to);
		}
	}

	return $graph;
}

##############
## GENERIC METRIC CONVERSIONS
## Since metric is clean we can specify two functions to deal with
## order-of-magnitude changes: one that multiplies by 10 and one that
## divides by 10.
##
## For these functions, order-of-magnitude refers to the raw number, not
## to the unit. (For example, going from centimeters to millimeters is an
## increase in OOM while from centimeters to meters is a decrease.)
##
## The functions 'metric_increase_magnitude' and 'metric_decrease_magnitude'
## are meta-functions; they take one parameter, the number of places that
## the magnitude should be changed. They return a function to handle the
## actual conversion.
##############
sub metric_increase_magnitude
{
	my ($order) = @_;

	return sub {
		my ($value) = @_;
		for (1..$order) {
			$value *= 10.0;
		}
		return $value;
	};
}

sub metric_decrease_magnitude
{
	my ($order) = @_;

	return sub {
		my ($value) = @_;

		for (1..$order) {
			$value /= 10.0;
		}

		return $value;
	}
}

##############
## TEMPERATURE CONVERSION FUNCTIONS
##############
sub celcius_to_fahrenheit
{
	my ($celcius) = @_;

	return ((9.0 * $celcius) / 5.0) + 32;
}

sub celcius_to_kelvin
{
	my ($celcius) = @_;

	return $celcius + 273.15;
}

sub fahrenheit_to_celcius
{
	my ($fahrenheit) = @_;

	return (5.0 * ($fahrenheit - 32)) / 9.0;
}

sub kelvin_to_celcius
{
	my ($kelvin) = @_;

	return $kelvin - 273.15;
}

##############
## DISTANCE CONVERSION FUNCTIONS
##############

sub astronomical_units_to_kilometers
{
	my ($au) = @_;

	return $au * 149_597_870.7;
}

sub centimeters_to_inches
{
	my ($centimeters) = @_;

	return $centimeters * 0.393700787;
}

sub feet_to_inches
{
	my ($feet) = @_;

	return $feet * 12;
}

sub feet_to_miles
{
	my ($feet) = @_;

	return $feet / 5280;
}

sub feet_to_yards
{
	my ($feet) = @_;

	return $feet / 3;
}

sub inches_to_centimeters
{
	my ($inches) = @_;

	return $inches / 0.393700787;
}

sub inches_to_feet
{
	my ($inches) = @_;

	return $inches / 12.0;
}

sub kilometers_to_astronomical_units
{
	my ($kilometers) = @_;

	return $kilometers / 149_597_870.7;
}

sub kilometers_to_light_years
{
	my ($kilometers) = @_;

	return $kilometers / 9_460_730_472_580.8;
}

sub light_seconds_to_light_years
{
	my ($lightSeconds) = @_;

	return $lightSeconds / 31_557_600.0;
}

sub light_years_to_light_seconds
{
	my ($lightYears) = @_;

	return $lightYears * 31_557_600;
}

sub light_years_to_kilometers
{
	my ($lightYears) = @_;

	return $lightYears * 9_460_730_472_580.8;
}

sub light_years_to_parsecs
{
	my ($lightYears) = @_;

	return $lightYears / 3.26156;
}

sub miles_to_feet
{
	my ($miles) = @_;

	return $miles * 5280;
}

sub miles_to_nautical_miles
{
	my ($miles) = @_;

	return $miles * 0.868976242;
}

sub nautical_miles_to_miles
{
	my ($nauticalMiles) = @_;

	return $nauticalMiles / 0.868976242;
}

sub parsecs_to_light_years
{
	my ($parsecs) = @_;

	return $parsecs * 3.26156;
}

sub yards_to_feet
{
	my ($yards) = @_;

	return $yards * 3;
}

##############
## TIME CONVERSION FUNCTIONS
##############
sub hours_to_minutes
{
	my ($hours) = @_;

	return $hours * 60;
}

sub minutes_to_hours
{
	my ($minutes) = @_;

	return $minutes / 60.0;
}

sub minutes_to_seconds
{
	my ($minutes) = @_;

	return $minutes * 60;
}

sub seconds_to_minutes
{
	my ($seconds) = @_;

	return $seconds / 60.0;
}

##############
## WEIGHT/MASS CONVERSION FUNCTIONS
##
## Assume standard earth gravity (9.8m/s^2)
## when converting between mass and weight.
##############

sub grams_to_kilgrams
{
	my ($grams) = @_;

	return $grams / 1000.0;
}

sub kilograms_to_grams
{
	my ($kilograms) = @_;

	return $kilograms * 1000.0;
}

sub kilograms_to_pounds
{
	my ($kilograms) = @_;

	return $kilograms * 2.20462262;
}

sub ounces_to_pounds
{
	my ($ounces) = @_;

	return $ounces / 16.0;
}

sub pounds_to_kilograms
{
	my ($pounds) = @_;

	return $pounds / 2.20462262;
}

sub pounds_to_ounces
{
	my ($pounds) = @_;

	return $pounds * 16.0;
}

sub pounds_to_stone
{
	my ($pounds) = @_;

	return $pounds * 0.0714286;
}

sub stone_to_pounds
{
	my ($stone) = @_;

	return $stone * 14;
}

##############
## VOLUME CONVERSION FUNCTIONS
##############
sub gallons_to_liters
{
	my ($gallons) = @_;

	return $gallons * 3.78541;
}

sub liters_to_gallons
{
	my ($liters) = @_;

	return $liters / 3.78541;
}

##############
## PRESSURE CONVERSION FUNCTIONS
##############
sub atmospheres_to_bars
{
	my ($atmospheres) = @_;

	return $atmospheres * 1.01325;
}

sub atmospheres_to_pascals
{
	my ($atmospheres) = @_;

	return $atmospheres * 101325;
}

sub atmospheres_to_psi
{
	my ($atmospheres) = @_;

	return $atmospheres * 14.69595;
}

sub bars_to_atmospheres
{
	my ($bars) = @_;

	return $bars * 0.98692;
}

sub bars_to_psi
{
	my ($bars) = @_;

	return $bars * 14.50377;
}

sub pascals_to_atmospheres
{
	my ($pascals) = @_;

	return $pascals * 0.00000986923267;
}

sub pascals_to_psi
{
	my ($pascals) = @_;

	return $pascals * 0.000145037738;
}

sub psi_to_atmospheres
{
	my ($psi) = @_;

	return $psi * 0.068046;
}

sub psi_to_bars
{
	my ($psi) = @_;

	return $psi * 0.068948;
}

sub psi_to_pascals
{
	my ($psi) = @_;

	return $psi * 6894.75729;
}

##############
## COMPUTER UNIT CONVERSIONS
##############
sub bits_to_bytes
{
	my ($bits) = @_;

	return $bits / 8;
}

sub bytes_to_bits
{
	my ($bytes) = @_;

	return $bytes * 8;
}

# e.g., mb -> kb
sub byte_order_of_magnitude_down
{
	my ($value) = @_;

	return $value * 1024.0;
}

sub byte_order_of_magnitude_up
{
	my ($value) = @_;

	return $value / 1024.0;
}

1;
