package Modules::Ignore;

#######
## PERL SETUP
#######
use strict;

#######
## SETUP
#######

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

	Modules::register_private('ignore', \&Modules::Ignore::ignore);
	Modules::register_private('unignore', \&Modules::Ignore::unignore);
}

#######
## MAIN
#######
sub ignore($)
{
	my $message = shift;

	my ($password, $nick) = split(/\s+/, $message->message(), 2);

	# Check that we have access for this
	unless (Modules::Access::check_access($message->from(), $password, 'ignore')) {
		return "You don't have access for that!";
	}

	# Add to ignore list
	Bot::add_ignore($nick);

	return "$nick has been added to the ignore list";
}

sub unignore($)
{
	my $message = shift;

	my ($password, $nick) = split(/\s+/, $message->message(), 2);

	# Check that we have access for this
	unless (Modules::Access::check_access($message->from(), $password, 'ignore')) {
		return "You don't have access for that!";
	}

	# Add to ignore list
	Bot::remove_ignore($nick);

	return "$nick has been removed from the ignore list";
}	

1;
