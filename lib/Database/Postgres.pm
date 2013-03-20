package Database::Postgres;

use strict;

use base qw/ Database::Base /;

sub connect
{
	my $self = shift;

	if ($self->{'_dbh'}) {
		$self->disconnect;
	}

	# Make sure enough data is present to connect
	unless ($self->{'database'} && $self->{'username'}) {
		$self->{'error'}->(Carp::longmess("Missing database or user name"), $self);
	}

	$self->{'_dbh'} = DBI->connect("DBI:Pg:database=$self->{'database'}", $self->{'username'}, $self->{'password'}) or $self->{'error'}->(Carp::longmess(DBI::errstr), $self);

	$self->{'_connected'} = 1;

	return $self;
}

sub insert_id()
{
	my $self = shift;

	die "Not Implemented";
}

1;
