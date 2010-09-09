package Modules::Replace;

#######
## PERL SETUP
#######
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

	&Modules::register_action('buttbuttinate', \&Modules::Replace::replace);
}

sub replace($)
{
	my $message = shift;

	my $data = $message->message();

	$data =~ s/ass/butt/gi;
	$data =~ s/tit/breast/gi;
	$data =~ s/sex/love/gi;
	$data =~ s/cock/penis/gi;
	$data =~ s/cunt/vagina/gi;
	$data =~ s/twat/vuvla/gi;

	return $data;
}

1;
