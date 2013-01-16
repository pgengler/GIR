package Database::Statement;

#######
## DESCRIPTION
#######
##
#######

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Database::Base;

#######
## INTERNAL CONSTANTS
#######
use constant _INACTIVE => 0;
use constant _PREPARED => 1;
use constant _EXECUTED => 2;

#######
## CONSTRUCTOR
#######
## Handles setup and default values for a new instance of a
## Database::Statement object.
#######
## Parameters:
##
##   $database
##   - The Database object that this statement should be run against
##
##   $statement
##   - A string representing the statement to run.
##
##   %options
##   - A hash of any options that should be set. Valid options are:
##     error
##     - A custom function to receive errors. Defaults to the parent Database
##       object's handler, or a simple function that merely die()s with the 
##       error text.
#######
sub new()
{
	my ($class, $database, $statement, %options) = @_;

	my $self = {
		'_database'  => $database,
		'_sth'       => undef,
		'_statement' => $statement,
		'_state'     => _INACTIVE,
		'error'      => \&error
	};

	foreach my $key (keys %options) {
		$self->{ $key } = $options{ $key };
	}

	bless $self, $class;

	return $self;
}

#######
## PREPARE
#######
## Prepares a SQL statement for later execution.
#######
## Parameters:
##
##   $statement_str [optional]
##   - A string representing the statement to run. If not provided, the
##     '_statement' property of the object is used.
##
## Return Value:
##   Returns the current Database::Statement object.
#######
sub prepare()
{
	my ($self, $statement_str) = @_;

	if ($statement_str) {
		$self->{'_statement'} = $statement_str;
	}

	unless ($self->{'_database'} && $self->{'_database'}->connected()) {
		$self->{'error'}->(Carp::longmess("No database connection active!"), $self);
	}

	$self->{'_sth'} = $self->{'_database'}->_handle()->prepare($self->{'_statement'});

	$self->{'_state'} = _PREPARED;

	return $self;
}

#######
## EXECUTE
#######
## Executes a previously-prepared SQL statement.
#######
## Parameters:
##
##   @values
##   - An array containing any parameters to be passed to the database to
##     execute query. This parameter is necessary if any '?' values were
##     used in the query.
##
## Return Value:
##   Returns the current Database::Statement object.
#######
sub execute()
{
	my ($self, @values) = @_;

	unless ($self->{'_database'} && $self->{'_database'}->connected()) {
		$self->{'error'}->(Carp::longmess("No database connection active!"), $self);
	}

	unless ($self->{'_sth'} && $self->{'_state'} >= _PREPARED) {
		$self->{'error'}->(Carp::longmess("Statement is not active; call prepare() first!"), $self);
	}

	$self->{'_sth'}->execute(@values) or $self->{'error'}->(Carp::longmess("Error executing query: " . $self->{'_sth'}->errstr()), $self);

	$self->{'_state'} = _EXECUTED;

	return $self;
}

#######
## NUMBER OF ROWS
#######
## Get the number of rows returned or affected by the last execution.
#######
## Parameters:
##
##   NONE
##
## Return Value:
##   The number of rows returned or affected by the last executed statement.
##   If no statement has been executed, returns -1.
#######
sub rows()
{
	my $self = shift;

	unless ($self->{'_sth'} && $self->{'_state'} == _EXECUTED) {
		return -1;
	}

	return $self->{'_sth'}->rows();
}

#######
## FETCH A ROW OF DATA
#######
## Fetches a row of data from the result of the last query.
#######
## Parameters:
##   $column [optional]
##     Optional column name. If provided, the value of that column is
##       returned (as a scalar).
##
## Return Value:
##   If $column parameter was provided:
##     Returns a scalar with the value of that column
##   If $column parameter was NOT provided:
##     In an array context, returns an array of all columns in the row.
##     Otherwise, returns a hash reference where the keys are the column names
##       and the values are the column value for that row.
#######
sub fetch()
{
	my ($self, $column) = @_;

	unless ($self->{'_database'} && $self->{'_database'}->connected()) {
		$self->{'error'}->(Carp::longmess("No database connection active"), $self);
	}

	unless ($self->{'_sth'} && $self->{'_state'} == _EXECUTED) {
		$self->{'error'}->(Carp::longmess("No active statement available to fetch from"), $self);
	}

	if (defined($column)) {
		return $self->{'_sth'}->fetchrow_hashref()->{ $column };
	} elsif (wantarray()) {
		return $self->{'_sth'}->fetchrow_array();
	} else {
		return $self->{'_sth'}->fetchrow_hashref();
	}
}

#######
## FETCH ALL ROWS OF DATA
#######
## Fetch all rows of data from the last query.
#######
## Parameters:
##   NONE
##
## Return Value:
##   Returns an arrayref, the elements of which are hashrefs for each row
##   of data (the same format as returned by fetch()).
#######
sub fetchall()
{
	my $self = shift;

	unless ($self->{'_database'} && $self->{'_database'}->connected()) {
		$self->{'error'}->(Carp::longmess("No database connection active"), $self);
	}

	unless ($self->{'_sth'} && $self->{'_state'} == _EXECUTED) {
		$self->{'error'}->(Carp::longmess("No active statement available to fetch from"), $self);
	}

	return $self->{'_sth'}->fetchall_arrayref({});
}

#######
## GET STATEMENT HANDLE
#######
## Return the statement handle for the current statement.
#######
## Parameters:
##
##   NONE
##
## Return Value:
##   Returns the statement handle for the current statement.
#######
sub handle()
{
	my $self = shift;

	return $self->{'_sth'};
}

#######
## ERROR HANDLING
#######
## This function is a default error-handler. It simply die()s with the error.
#######
## Parameters:
##
##   $message
##   - a string containing the error message
##
##   $obj
##   - the object that caused the error
##
## Return value:
##   NONE
##
## By passing a function as the 'error' parameter during construction, a
## custom function can override this behavior.
#######
sub error()
{
	my ($message, $obj) = @_;

	die $message;
}

1;
