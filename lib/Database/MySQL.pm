package Database::MySQL;

use strict;

use base qw/ Database::Base /;

sub connect()
{
	my $self = shift;

	if ($self->{'_dbh'}) {
		$self->disconnect();
	}

	# Default to 'localhost'
	$self->{'host'} ||= 'localhost';
	# Default to port 3306
	$self->{'port'} ||= 3306;
	# UTF-8 support should be enabled by default
	$self->{'enable_utf8'} = 1 unless defined($self->{'enable_utf8'});

	# Make sure enough data is present to connect
	unless ($self->{'database'} && $self->{'username'}) {
		$self->{'error'}->(Carp::longmess("Missing database or user name"), $self);
	}

	$self->{'_dbh'} = DBI->connect("DBI:mysql:$self->{'database'}:$self->{'host'}:$self->{'port'};mysql_enable_utf8=$self->{'enable_utf8'}", $self->{'username'}, $self->{'password'}) or $self->{'error'}->(Carp::longmess(DBI::errstr), $self);

	$self->{'_connected'} = 1;

	return $self;
}

sub insert_id()
{
	my $self = shift;

	return $self->{'_dbh'}->{'mysql_insertid'};
}

1;
