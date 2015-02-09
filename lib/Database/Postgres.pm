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

	my $connectString = "DBI:Pg:database=$self->{'database'}";
	if ($self->{'host'}) {
		$connectString .= ";host=$self->{'host'}";
	}
	if ($self->{'port'}) {
		$connectString .= ";port=$self->{'port'}";
	}

	$self->{'_dbh'} = DBI->connect($connectString, $self->{'username'}, $self->{'password'}) or $self->{'error'}->(Carp::longmess(DBI::errstr), $self);

	$self->{'_connected'} = 1;

	return $self;
}

sub insert_id
{
	my $self = shift;
	my ($table, $column) = @_;

	unless (defined($table) && defined($column)) {
		die "Database::Postgres::insert_id requires both table and column name";
	}

	my $sql = q(
		SELECT currval(pg_get_serial_sequence(?, ?)) AS id
	);
	my $statement = $self->query($sql, $table, $column);

	return $statement->fetch('id');
}

1;
