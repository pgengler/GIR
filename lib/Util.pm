package Util;

use strict;
use warnings;
use parent 'Exporter';

use LWP::UserAgent;

our @EXPORT = qw/ get_url /;

sub get_url($)
{
	my ($url) = @_;

	my $agent = LWP::UserAgent->new;
	my $response = $agent->get($url);

	unless ($response->is_success) {
		die $response->status_line;
	}

	return $response->content;
}

1;
