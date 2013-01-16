package GIR::Util;

use v5.10;
use strict;
use warnings;
use parent 'Exporter';

use Database::MySQL;

use LWP::UserAgent;

our @EXPORT = qw/ db get_url /;

sub db()
{
	state $db;

	unless (defined $db) {
		$db = Database::MySQL->new(
			'database' => $GIR::Bot::config->{'database'}->{'name'},
			'password' => $GIR::Bot::config->{'database'}->{'password'},
			'username' => $GIR::Bot::config->{'database'}->{'user'},
		);
	}

	return $db;
}

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
