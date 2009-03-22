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

sub lookup()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $packed_ip = gethostbyname($data);

	if (defined($packed_ip)) {
		return "$data resolves to " . inet_ntoa($packed_ip);
	} else {
		return 'Host not found' if $addressed;
	}
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'host <name>': looks up the IP address for the given host.";
}

1;
