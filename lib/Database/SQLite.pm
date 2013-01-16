package Database::SQLite;

use strict;

use base qw/ Database::Base /;

sub connect()
{
	my $self = shift;

	if ($self->{'_dbh'}) {
		$self->disconnect();
	}

	# Make sure enough data is present to connect
	unless ($self->{'database'}) {
		$self->{'error'}->(Carp::longmess("Missing database name"), $self);
	}

	$self->{'_dbh'} = DBI->connect("DBI:SQLite:$self->{'database'}") or $self->{'error'}->(Carp::longmess(DBI::errstr), $self);

	$self->{'_connected'} = 1;

	return $self;
}

sub insert_id()
{
	my $self = shift;

	return $self->{'_dbh'}->last_insert_id("","","","");
}

1;
