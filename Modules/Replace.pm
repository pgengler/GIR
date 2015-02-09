package Modules::Replace;

use strict;

sub register
{
	GIR::Modules::register_action('buttbuttinate', \&Modules::Replace::replace);
}

sub replace
{
	my $message = shift;

	my $data = $message->message;

	$data =~ s/ass/butt/gi;
	$data =~ s/tit/breast/gi;
	$data =~ s/sex/love/gi;
	$data =~ s/cock/penis/gi;
	$data =~ s/cunt/vagina/gi;
	$data =~ s/twat/vuvla/gi;

	return $data;
}

1;
