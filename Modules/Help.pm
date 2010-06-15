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
	my $params = shift;

	return unless ($params->{'addressed'} || $params->{'type'} eq 'private');

	if ($params->{'message'}) {
		if ($Modules::help{ $params->{'message'} }) {
			return $Modules::help{ $params->{'message'} }->($params);
		} else {
			return "No help is available for '$params->{'message'}'";
		}
	} else {
		my @topics = sort { $a cmp $b } keys %Modules::help;
		return 'Type "help <command>" for help on a specific command; available commands are: ' . join(', ', @topics);
	}
}

1;
