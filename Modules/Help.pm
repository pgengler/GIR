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

	if ($message->message()) {
		my $target = $message->message();
		if ($Modules::help{ $target }) {
			return $Modules::help{ $target }->($message);
		} else {
			return "No help is available for '$target'";
		}
	} else {
		my @topics = sort { $a cmp $b } keys %Modules::help;
		return 'Type "help <command>" for help on a specific command; available commands are: ' . join(', ', @topics);
	}
}

1;
