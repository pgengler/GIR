package Modules::DNS;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Socket;

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

	&Modules::register_action('host', \&Modules::DNS::lookup);

	&Modules::register_help('host', \&Modules::DNS::help);
}

sub lookup($)
{
	my $message = shift;

	my $hostname = $message->message();
	my $packed_ip = gethostbyname($hostname);

	if (defined($packed_ip)) {
		return "$hostname resolves to " . inet_ntoa($packed_ip);
	} else {
		&Bot::status("Host '$hostname' not found.");
		return 'Host not found' if $message->is_addressed();
	}
}

sub help($)
{
	my $message = shift;

	return "'host <name>': looks up the IP address for the given host.";
}

1;
