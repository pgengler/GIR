package Modules::Help;

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

	&Modules::register_action('help', \&Modules::Help::process);
}

sub process($)
{
	my $message = shift;

	return unless $message->is_explicit();

	my $topic = $message->message();

	if ($topic && $topic !~ /^\s*help\s*$/) {
		if ($Modules::help{ $topic }) {
			return $Modules::help{ $topic }->($message);
		} else {
			return "No help is available for '$topic'";
		}
	} else {
		my @topics = sort { $a cmp $b } keys %Modules::help;
		return 'Type "help <command>" for help on a specific command; available commands are: ' . join(', ', @topics);
	}
}

1;
