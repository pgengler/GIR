package Modules::Text;

use strict;

##############
sub new { bless { }, shift }

sub register
{
	my $self = shift;

	GIR::Modules::register_action('lc', \&do_lc);
	GIR::Modules::register_action('lcfirst', \&do_lcfirst);
	GIR::Modules::register_action('reverse', \&do_reverse);
	GIR::Modules::register_action('uc', \&do_uc);
	GIR::Modules::register_action('uc', \&do_ucfirst);
}

sub do_lc
{
	my ($message) = @_;

	return lc($message->message);
}

sub do_lcfirst
{
	my ($message) = @_;

	return lcfirst($message->message);
}

sub do_reverse($)
{
	my $message = shift;

	return reverse $message->message;
}

sub do_uc
{
	my ($message) = @_;

	return uc($message->message);
}

sub do_ucfirst
{
	my ($message) = @_;

	return ucfirst($message->message);
}

1;
