package Modules::Say;

use strict;

sub register
{
	GIR::Modules->register_action('say', \&Modules::Say::say, 2);
	GIR::Modules->register_action('action', \&Modules::Say::action, 2);

	GIR::Modules->register_help('say', \&Modules::Say::help);
	GIR::Modules->register_help('action', \&Modules::Say::help);
}

sub say
{
	my $message = shift;

	my ($target, $msg) = split(/\s+/, $message->message, 2);

	return undef unless $target && $msg;

	if ($message->is_public) {
		GIR::Bot->enqueue_say($target, $msg);
		return "OK, " . $message->from;
	}
}

sub action
{
	my $message = shift;

	my ($target, $msg) = split(/\s+/, $message->message, 2);

	return undef unless $target && $msg;

	if ($message->is_public) {
		GIR::Bot->enqueue_action($target, $msg);
		return "OK, " . $message->from;
	}
}

sub help
{
	my $message = shift;

	return "Usage: 'say <channel/user> <message>' or 'action <channel/user> <message>'\nSay <message> or do a /me <action> in the given channel or target user. I'll probably need to be in the channel.";
}

1;
