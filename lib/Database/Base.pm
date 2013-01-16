package Database::Base;

#######
## DESCRIPTION
#######
## This module provides a base class for database objects. It provides several
## common methods. Subclassing objects are responsible for providing database-
## specific implementation detail, such as actually connecting to a database.
##
## The following methods must be provided by subclassing objects:
##   connect()
##   - connect to the database. If the connection is successful, the database
##     handle should be stored in '_dbh' and '_connected' should be set to a
##     true value.
#######

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use DBI;

use Database::Statement;

#######
## CONSTRUCTOR
#######
## Construct a new Database object.
#######
## This method is intended to be common to all subclassing objects; a
## Database object should never be created directly.
##
## This contructor sets initial values for several properties and calls the
## 'connect()' method (which must be provided by subclassing objects).
##
## This constructor can accept a hash of options; initial values are
## overridden by values set in this options hash.
##
## These options exist for all Database objects:
##   error
##   - a function to display database errors. If not provided, the default
##     behavior is just to die() with the error. This function is passed
##     along to Database::Statement objects for them to use in case of errors.
##     Error handling functions are passed two parameter: first is a string
##     with the error message; send is the object that caused the error.
##
##   auto_prepare
##   - controls whether new Database::Statement objects should have their
##     'prepare()' method called automatically. By default, this option
##     is enabled; set to 0 to disable.
##     If this option is disabled, client code will need to call the
##     'prepare()' method of a Database::Statement object before calling
##     its 'execute()' method.
##
## Other values that may be passed as options include database connection
## information, such as username, password, server name, etc. However, these
## are all database-specific. See the documentation for a particular
## Database subclass for more information about connection options.
#######
sub new()
{
	my ($class, %params) = @_;

	my $self = {
		'_dbh'          => undef,
		'_connected'    => 0,
		'error'         => \&error,
		'auto_prepare'  => 1
	};

	foreach my $key (keys %params) {
		# Don't let anything from %params clobber internal properties
		next if $key =~ /^_/;
		$self->{ $key } = $params{ $key };
	}

	bless $self, $class;

	$self->connect();

	return $self;
}

#######
## CONNECTED
#######
## Determine if a database connection exists.
#######
## Parameters:
##   NONE
##
## Return value:
##   If a valid DBI object exists and is marked as connected, returns true.
##   Otherwise, returns false.
##
## This method simply checks that the object is valid and that the '_connected'
## property is not false. If additional checking is desired (for example, to
## check whether the database connection was closed), a subclassing object can
## override this method.
#######
sub connected()
{
	my $self = shift;

	return defined($self->{'_dbh'}) && $self->{'_connected'};
}

#######
## DISCONNECT
#######
## This method disconnects the class from the database.
#######
## Parameters:
##   NONE
##
## Return value:
##   NONE
#######
sub disconnect()
{
	my $self = shift;

	unless ($self->{'_dbh'}) {
		$self->{'error'}->(Carp::longmess("No active connection to disconnect from"), $self);
	}

	$self->{'_dbh'}->disconnect();

	undef $self->{'_dbh'};
}

#######
## INITIALIZE NEW STATEMENT
#######
## This method creates a new Database::Statement object for the given SQL.
#######
## Parameters:
##
##   $sql
##   - This is the string corresponding to the database statement.
##
##   $auto_prepare [optional]
##   - This allows overriding of the 'auto_prepare' property of the
##     Database object. If this parameter is provided, its value is
##     controlling; otherwise, the value of the 'auto_prepare' property is
##     used.
##
## Return value:
##
##   Returns a new Database::Statement object for the given statement.
##   If the auto_prepare option is enabled, the statement is prepared before
##   returning it.
#######
sub statement()
{
	my ($self, $sql, $auto_prepare) = @_;

	unless ($self->{'_dbh'}) {
		$self->{'error'}->("No database connection active.");
	}

	my $statement = Database::Statement->new($self, $sql, 'error' => $self->{'error'});

	if ($auto_prepare || (not defined($auto_prepare) && $self->{'auto_prepare'})) {
		$statement->prepare();
	}

	return $statement;
}

#######
## RUN NEW QUERY
#######
## This method creates a new Database::Statement object for the given SQL and
## executes it with the given parameters. It is equivalent to a calling
## Database::Base#statement and then Database::Statement#execute.
#######
## Parameters:
##
##   $sql
##   - This is the string corresponding to the query to be executed.
##
##   @values [optional]
##   - array of values passed to #execute (to provide values for placeholders)
##
## Return Value:
##
##   Returns the Database::Statement object with the query active.
#######
sub query()
{
	my $self = shift;
	my ($sql, @values) = @_;

	return $self->statement($sql, 1)->execute(@values);
}

#######
## START A TRANSACTION
#######
## This method starts a new database transaction.
#######
## Parameters:
##   NONE
##
## Return value:
##   NONE
#######
sub start_transaction()
{
	my $self = shift;

	# Abort if we're already in a transaction
	if ($self->{'_transaction'}) {
		$self->{'error'}->(Carp::longmess("Cannot start new transaction; one is already active."), $self);
	}

	$self->statement("BEGIN", 1)->execute();

	$self->{'_transaction'} = 1;
}

#######
## COMMIT A TRANSACTION
#######
## This method tells the database to commit the current transaction.
#######
## Parameters:
##    NONE
##
## Return value:
##   NONE
#######
sub commit_transaction()
{
	my $self = shift;

	# Abort if we're not in a transaction
	unless ($self->{'_transaction'}) {
		$self->{'error'}->(Carp::longmess("No active transaction to commit"), $self);
	}

	$self->statement('COMMIT', 1)->execute();

	$self->{'_transaction'} = 0;
}

#######
## ROLL A TRANSACTION BACK
#######
## This method tells the database to roll the current transaction back.
#######
## Parameters:
##    NONE
##
## Return value:
##   NONE
#######
sub rollback_transaction()
{
	my $self = shift;

	# Abort if we're not in a transaction
	unless ($self->{'_transaction'}) {
		$self->{'error'}->(Carp::longmess("No active transaction to roll back"), $self);
	}

	$self->statement('ROLLBACK', 1)->execute();

	$self->{'_transaction'} = 0;
}	

#######
## GET DATABASE HANDLE
#######
## Returns the database handle for the current connection.
#######
## Parameters:
##   NONE
##
## Return value:
##
##   The database handle for the current database connection.
##
## This method is not meant to be called directly from client code, but is
## available if needed. It is primarily intended for use by
## Database::Statement objects.
#######
sub _handle()
{
	my $self = shift;

	return $self->{'_dbh'};
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
