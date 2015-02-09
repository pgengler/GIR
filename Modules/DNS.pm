package Modules::DNS;

use strict;

use Socket;

sub register
{
	GIR::Modules->register_action('host', \&Modules::DNS::lookup);

	GIR::Modules->register_help('host', \&Modules::DNS::help);
}

sub lookup
{
	my $message = shift;

	my $hostname = $message->message;
	my $packed_ip = gethostbyname($hostname);

	if (defined($packed_ip)) {
		return "$hostname resolves to " . inet_ntoa($packed_ip);
	} else {
		GIR::Bot->status("Host '%s' not found.", $hostname);
		return 'Host not found' if $message->is_addressed;
	}
}

sub help
{
	my $message = shift;

	return "'host <name>': looks up the IP address for the given host.";
}

1;
