package Modules::Help;

use strict;

sub register
{
	GIR::Modules::register_action('help', \&Modules::Help::process);
}

sub process($)
{
	my $message = shift;

	return unless $message->is_explicit();

	my $topic = $message->message();

	if ($topic && $topic !~ /^\s*help\s*$/) {
		if ($GIR::Modules::help{ $topic }) {
			return $GIR::Modules::help{ $topic }->($message);
		} else {
			return "No help is available for '$topic'";
		}
	} else {
		my @topics = sort { $a cmp $b } keys %GIR::Modules::help;
		return 'Type "help <command>" for help on a specific command; available commands are: ' . join(', ', @topics);
	}
}

1;
