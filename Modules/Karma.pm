package Modules::Karma;

use strict;
use lib ('./', '../Main');

use Database::MySQL;

sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}


sub register()
{
	my $this = shift;

	&Modules::register_action('karma', \&Modules::Karma::get);
	&Modules::register_action('REGEXP:^(.+)(\+\+|\-\-)$', \&Modules::Karma::update);
}

sub get($)
{
	my $message = shift;

	my $name = $message->message();

	return unless $name;

	my $karma = 0;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	my $query = qq~
		SELECT name, karma
		FROM karma
		WHERE LOWER(name) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute(lc($name));

	if ($sth) {
		my $user = $sth->fetchrow_hashref();
		if ($user && $user->{'karma'}) {
			$karma = $user->{'karma'};
		}
	}

	if ($karma) {
		return "$name has karma of $karma";
	} else {
		return "$name has neutral karma";
	}
}

sub update($)
{
	my $message = shift;

	unless ($message->is_public()) {
		return 'Karma updates must be done in public!';
	}

	# Parse message for name and direction
	my $name;
	my $direction;
	if ($message->message() =~ /^(.+)(\+\+|\-\-)$/) {
		$name      = $1;
		$direction = $2;
	} else {
		return;
	}

	if (lc($message->from()) eq lc($name)) {
		return "You can't change your own karma!";
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Check if entry already exists
	my $query = qq~
		SELECT name
		FROM karma
		WHERE name = ?
	~;
	$db->prepare($query);
	my $sth = $db->execute(lc($name));
	my $karma = $sth->fetchrow_hashref();

	if ($karma) {
		if ($direction eq '++') {
			$query = qq~
				UPDATE karma SET
					karma = karma + 1
				WHERE LOWER(name) = LOWER(?)
			~;
		} elsif ($direction eq '--') {
			$query = qq~
				UPDATE karma SET
					karma = karma - 1
				WHERE LOWER(name) = LOWER(?)
			~;
		}
		$db->prepare($query);
		$db->execute(lc($name));
	} else {
		$query = qq~
			INSERT INTO karma
			(name, karma)
			VALUES
			(?, ?)
		~;
		$db->prepare($query);
		$db->execute(lc($name), $direction eq '--' ? -1 : 1);
	}
	return undef;
}

1;
