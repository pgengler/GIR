package Modules::Time;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Acme::Time::Asparagus;
use Time::Beat;

#######
## GLOBALS
#######


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

	&Modules::register_action('time', \&Modules::Time::select);
	&Modules::register_action('unixtime', \&Modules::Time::unix_time);
	&Modules::register_action('localtime', \&Modules::Time::local_time);
	&Modules::register_action('gmtime', \&Modules::Time::gm_time);
	&Modules::register_action('swatch', \&Modules::Time::swatch);
	&Modules::register_action('veggietime', \&Modules::Time::veggie);

	&Modules::register_help('time', \&Modules::Time::help);
}

sub select($)
{
	my $message = shift;

	return undef unless $message->message() =~ /^\s*time\s*$/;

	my @times = ('unix', 'local', 'gmt', 'swatch', 'veggie');
	my $time = $times[int(rand(scalar(@times)))];

	if ($time eq 'unix') {
		return &unix_time($message);
	} elsif ($time eq 'local') {
		return &local_time($message);
	} elsif ($time eq 'gmt') {
		return &gm_time($message);
	} elsif ($time eq 'swatch') {
		return &swatch($message);
	} elsif ($time eq 'veggie') {
		return &veggie($message);
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

	return '@' . &Time::Beat::beats(time());
}

sub veggie($)
{
	my $message = shift;

	return &Acme::Time::Asparagus::veggietime();
}

sub help($)
{
	my $message = shift;

	my $str = "time: Returns the current time in one of several possible formats.\n";
	$str .= "'time' chooses one of the following formats randomly; they can also be accessed individually:\n";
	$str .= "'unixtime' displays the current UNIX timestamp. 'localtime' displays a human-formatted string of the current local time for my timezone.\n";
	$str .= "'gmtime' is like 'localtime' but uses UTC/GMT. 'swatch' displays Swatch time. 'veggietime' displays the time using vegetables.";

	return $str;
}

1;
