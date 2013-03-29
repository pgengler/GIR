package Migrate;

use strict;
use warnings;
use feature 'say';

use DBI;

use parent 'Exporter';
our @EXPORT_OK = qw/ copy_table /;

our $POSTGRES_DATABASE = 'ircbot';
our $POSTGRES_USERNAME = 'ircbot';
our $POSTGRES_PASSWORD = '<db password>';

our $MYSQL_DATABASE = 'ircbot';
our $MYSQL_USERNAME = 'ircbot';
our $MYSQL_PASSWORD = '<db password>';

sub mysql
{
	DBI->connect("DBI:mysql:${MYSQL_DATABASE}", $MYSQL_USERNAME, $MYSQL_PASSWORD) or die "Can't connect to MySQL DB: ${DBI::errstr}";
}

sub postgres
{
	my $dbh = DBI->connect("DBI:Pg:database=${POSTGRES_DATABASE}", $POSTGRES_USERNAME, $POSTGRES_PASSWORD) or die "Can't connect to Postgres database: ${DBI::errstr}";
	$dbh->do("set client_encoding='utf8'");
	return $dbh;
}

sub truncate_table($)
{
	my ($table) = @_;

	my $sql = qq(
		TRUNCATE TABLE ${table}
	);
	postgres->do($sql);
}

sub copy_table($$)
{
	my ($table, $columns) = @_;

	say "Copying data in '${table}'";

	my $mysql = mysql();
	my $postgres = postgres();

	my $mysql_column_string    = join(', ', map { $mysql->quote_identifier($_) } @$columns);
	my $postgres_column_string = join(', ', map { $postgres->quote_identifier($_) } @$columns);
	my $placeholder_string     = join(', ', map { '?' } @$columns);

	my $select_sql = qq(
		SELECT ${mysql_column_string}
		FROM ${table}
	);

	my $insert_sql = qq(
		INSERT INTO ${table}
		(${postgres_column_string})
		VALUES
		(${placeholder_string})
	);

	my $select = $mysql->prepare($select_sql) or die "Unable to prepare SELECT: ${mysql::errstr}";
	my $insert = $postgres->prepare($insert_sql) or die "Unable to prepare INSERT: ${postgres::errstr}";

	truncate_table($table);

	$select->execute;

	while (my $row = $select->fetchrow_arrayref) {
		foreach my $item (@$row) {
			utf8::decode($item);
		}
		$insert->execute(@$row);
	}
}

1;
