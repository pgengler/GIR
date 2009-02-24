package Modules::Say;

#######
## PERL SETUP
#######
use strict;

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

	&Modules::register_action('say', \&Modules::Say::say);
	&Modules::register_action('action', \&Modules::Say::action);
}

sub say()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my ($target, $message) = split(/\s+/, $data, 2);

	&Bot::say($target, $message);

	return "OK, $user";
}

sub action()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my ($target, $message) = split(/\s+/, $data, 2);

	&Bot::action($target, $message);

	return "OK, $user";
}

1;
