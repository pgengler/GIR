package Database::SQLite;

use strict;

use Carp;
use DBI;

sub new()
{
	my $pkg = shift;
	my $obj = { 
		'queries'		=> 0,
		'database'  => '',
		'dbh'				=> undef,
		'error'     => undef
	};
	bless $obj, $pkg;
	return $obj;
}

sub init()
{
	my $this = shift;
	my ($database, $error) = @_;

	if ($error) {
		$this->{'error'} = $error;
	} else {
		$this->{'error'} = \&error;
	}
	$this->{'dbh'} = DBI->connect("DBI:SQLite:$database") or $this->{'error'}->(Carp::longmess(DBI::errstr), 1);
}

sub close()
{
	my $this = shift;
	$this->{'dbh'}->disconnect();
}

sub query()
{
	my ($this, $query) = @_;
	$this->{'sth'} = $this->{'dbh'}->prepare($query);
	$this->{'query'} = $query;
	$this->{'sth'}->execute() or $this->{'error'}->(Carp::longmess("Couldn't execute statement: " . $this->{'sth'}->errstr . " in query " . $query), 1);
	$this->{'queries'}++;
	return $this->{'sth'};
}

sub prepare()
{
	my ($this, $query) = @_;
	$this->{'sth'} = $this->{'dbh'}->prepare($query);
	$this->{'query'} = $query;
	return $this->{'sth'};
}

sub execute()
{
	my ($this, @params) = @_;
	return unless $this->{'sth'};
	$this->{'sth'}->execute(@params) or $this->{'error'}->(Carp::longmess("Couldn't execute statement: " . $this->{'sth'}->errstr . " in query " . $this->{'query'}), 1);
	return $this->{'sth'};
}

sub finish()
{
	my $this = shift;
	return unless $this->{'sth'};
	$this->{'sth'}->finish();
}

sub start_transaction()
{
	my $this = shift;

	# Abort if we're already in a transaction
	if ($this->{'transaction'}) {
		return;
	}

	my $sth = $this->{'dbh'}->prepare('BEGIN');
	$sth->execute();
	$this->{'transaction'} = 1;
}

sub commit_transaction()
{
	my $this = shift;

	# Abort if we're not in a transaction
	unless ($this->{'transaction'}) {
		return;
	}

	my $sth = $this->{'dbh'}->prepare('COMMIT');
	$sth->execute();
	$this->{'transaction'} = 0;
}

sub rollback_transaction()
{
	my $this = shift;

	# Abort if we're not in a transaction
	unless ($this->{'transaction'}) {
		return;
	}

	$this->{'dbh'}->prepare('ROLLBACK');
	$this->{'dbh'}->execute();
	$this->{'transaction'} = 0;
}	

sub num_queries()
{
	my $this = shift;
	return $this->{'queries'};
}

sub insert_id()
{
	my $this = shift;
	return $this->{'dbh'}->last_insert_id();
}

sub error()
{
	my $message = shift;

	die $message;
}

1;
