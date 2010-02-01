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

	&Modules::register_action('say', \&Modules::Say::say, 2);
	&Modules::register_action('action', \&Modules::Say::action, 2);

	&Modules::register_help('say', \&Modules::Say::help);
	&Modules::register_help('action', \&Modules::Say::help);
}

sub say()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my ($target, $message) = split(/\s+/, $data, 2);

	if ($type eq 'private' || $addressed == 1) {
		&Bot::say($target, $message);
		return "OK, $user";
	}
}

sub action()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my ($target, $message) = split(/\s+/, $data, 2);

	if ($type ne 'public' || $addressed == 1) {
		&Bot::action($target, $message);
		return "OK, $user";
	}
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "Usage: 'say <channel/user> <message>' or 'action <channel/user> <message>'\nSay <message> or do a /me <action> in the given channel or target user. I'll probably need to be in the channel.";
}

1;
