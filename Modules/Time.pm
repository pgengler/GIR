package Modules::Time;

use strict;

our $_useSwatch = 0;
our $_useVeggie = 0;

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

	eval {
		require Time::Beat;
	};
	$_useSwatch = 1 unless $@;
	eval {
		require Acme::Time::Asparagus;
	};
	$_useVeggie = 1 unless $@;

	GIR::Modules::register_action('time', \&Modules::Time::select);
	GIR::Modules::register_action('unixtime', \&Modules::Time::unix_time);
	GIR::Modules::register_action('localtime', \&Modules::Time::local_time);
	GIR::Modules::register_action('gmtime', \&Modules::Time::gm_time);
	GIR::Modules::register_action('swatch', \&Modules::Time::swatch) if $_useSwatch;
	GIR::Modules::register_action('veggietime', \&Modules::Time::veggie) if $_useVeggie;

	GIR::Modules::register_help('time', \&Modules::Time::help);
}

sub select($)
{
	my $message = shift;

	return undef unless $message->message() =~ /^\s*time\s*$/;

	my @times = qw/ unix local gmt /;
	push @times, 'swatch' if $_useSwatch;
	push @times, 'veggie' if $_useVeggie;

	my $time = $times[int(rand(scalar(@times)))];

	if ($time eq 'unix') {
		return unix_time($message);
	} elsif ($time eq 'local') {
		return local_time($message);
	} elsif ($time eq 'gmt') {
		return gm_time($message);
	} elsif ($_useSwatch && $time eq 'swatch') {
		return swatch($message);
	} elsif ($_useVeggie && $time eq 'veggie') {
		return veggie($message);
	}
}

sub unix_time($)
{
	my $message = shift;

	return time() . '';
}

sub local_time($)
{
	my $message = shift;

	my @parts = localtime(time());

	return localtime(time()) . ($parts[8] ? ' EDT' : ' EST');
}

sub gm_time($)
{
	my $message = shift;

	return gmtime(time()) . ' UTC';
}

sub swatch($)
{
	my $message = shift;

	return undef unless $_useSwatch;

	return '@' . Time::Beat::beats(time());
}

sub veggie($)
{
	my $message = shift;

	return undef unless $_useVeggie;

	return Acme::Time::Asparagus::veggietime();
}

sub help($)
{
	my $message = shift;

	my $str = q(time: Returns the current time in one of several possible formats.
'time' chooses one of the following formats randomly; they can also be accessed individually:
'unixtime' displays the current UNIX timestamp. 'localtime' displays a human-formatted string of the current local time for my timezone.
'gmtime' is like 'localtime' but uses UTC/GMT.);

	if ($_useSwatch) {
		$str .= q( 'swatch' displays Swatch (beat) time.);
	}
	if ($_useVeggie) {
		$str .= q( 'veggietime' displays the time using vegetables.);
	}

	return $str;
}

1;
