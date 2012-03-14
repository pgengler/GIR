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

	Modules::register_action('rot13', \&Modules::Rot13::rot13);

	Modules::register_help('rot13', \&Modules::Rot13::help);
}

sub rot13($)
{
	my $message = shift;

	my $data = $message->message();
	$data =~ y/A-Za-z/N-ZA-Mn-za-m/;

	return $data;
}

sub help($)
{
	my $message = shift;

	return "'rot13 <text>': Performs the ROT13 operation on the given text.";
}

1;
