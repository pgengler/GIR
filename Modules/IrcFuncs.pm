package Modules::IrcFuncs;

use strict;

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

	&Modules::register_action('help op', \&Modules::IrcFuncs::help_op);
	&Modules::register_action('op', \&Modules::IrcFuncs::op);

	&Modules::register_action('help deop', \&Modules::IrcFuncs::help_deop);
	&Modules::register_action('deop', \&Modules::IrcFuncs::deop);

	&Modules::register_action('help kick', \&Modules::IrcFuncs::help_kick);
	&Modules::register_action('kick', \&Modules::IrcFuncs::kick);

	&Modules::register_action('nick', \&Modules::IrcFuncs::change_nick);
}

sub help_op()
{
	my ($type, $user, $message, $where) = @_;

	# Only deal with PMs
	unless ($type eq 'private') {
		return;
	}

	return 'Syntax: op <password> <channel> [<user>]';
}

sub op()
{
	my ($type, $user, $message, $where) = @_;

	# Split into parts
	my ($password, $channel, $target) = split(/\s+/, $message);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'op')) {
		return "You don't have permission to do that, $user!";
	}

	&Bot::give_op($channel, $target || $user);

	return 'NOREPLY';
}

sub help_deop()
{
	my ($type, $user, $message, $where) = @_;

	# Only deal with PMs
	unless ($type eq 'private') {
		return;
	}

	return 'Syntax: deop <password> <channel> [<user>]';
}

sub deop()
{
	my ($type, $user, $message, $where) = @_;

	# Split into parts
	my ($password, $channel, $target) = split(/\s+/, $message);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'deop')) {
		return "You don't have permission to do that, $user!";
	}

	&Bot::take_op($channel, $target || $user);

	return 'NOREPLY';
}

sub help_kick()
{
	my ($type, $user, $message, $where) = @_;

	# Only deal with PMs
	unless ($type eq 'private') {
		return;
	}

	return 'Syntax: kick <password> <channel> <user> [<reason>]';
}

sub kick()
{
	my ($type, $user, $message, $where) = @_;

	# Split into parts
	my ($password, $channel, $target, $reason) = split(/\s+/, $message, 4);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'kick')) {
		return "You don't have permission to do that, $user!";
	}

	&Bot::kick($channel, $target, $reason);

	return 'NOREPLY';
}

sub change_nick()
{
	my ($type, $user, $message, $where) = @_;

	# Split into parts
	my ($password, $nick) = split(/\s+/, $message, 2);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'nick')) {
		return "You don't have permission to do that, $user!";
	}

	# Change nickname
	&Bot::change_nick($nick);

	return 'NOREPLY';
}

1;
