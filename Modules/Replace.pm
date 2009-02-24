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

sub replace()
{
	my ($who, $text) = @_;

	$text =~ s/ass/butt/gi;
	$text =~ s/tit/breast/gi;
	$text =~ s/sex/love/gi;
	$text =~ s/cock/penis/gi;
	$text =~ s/cunt/vagina/gi;

	return $text;
}

1;
