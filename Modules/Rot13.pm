package Modules::Rot13;

use strict;

sub register
{
	GIR::Modules::register_action('rot13', \&Modules::Rot13::rot13, 2);

	GIR::Modules::register_help('rot13', \&Modules::Rot13::help);
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
