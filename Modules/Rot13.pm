package Modules::Rot13;

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

	&Modules::register_action('rot13', \&Modules::Rot13::rot13);

	&Modules::register_help('rot13', \&Modules::Rot13::help);
}

sub rot13()
{
	my ($type, $user, $data, $where) = @_;

	$data = 

	return $data;
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'rot13 <text>': Performs the ROT13 operation on the given text.";
}

1;
