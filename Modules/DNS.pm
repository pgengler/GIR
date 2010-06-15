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
	my $params = shift;

	my $packed_ip = gethostbyname($params->{'message'});

	if (defined($packed_ip)) {
		return "$params->{'message'} resolves to " . inet_ntoa($packed_ip);
	} else {
		return 'Host not found' if $params->{'addressed'};
	}
}

sub help($)
{
	my $params = shift;

	return "'host <name>': looks up the IP address for the given host.";
}

1;
