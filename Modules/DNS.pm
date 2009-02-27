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


1;
