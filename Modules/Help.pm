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

sub process()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return unless ($addressed || $type eq 'private');

	if ($data) {
		if ($Modules::help{ $data }) {
			return $Modules::help{ $data }->($type, $user, $data, $where, $addressed);
		} elsif ($addressed || $type eq 'private') {
			return "No help is available for '$data'";
		}
	} else {
		my @topics = sort { $a cmp $b } keys %Modules::help;
		return 'Type "help <command>" for help on a specific command; available commands are: ' . join(', ', @topics);
	}
}

1;
