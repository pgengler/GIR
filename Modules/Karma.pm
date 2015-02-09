package Modules::Karma;

use strict;

my $update_expr = qr/^(.+)(\+\+|\-\-)$/;

sub register
{
	GIR::Modules->register_action('karma', \&Modules::Karma::get);
	GIR::Modules->register_action($update_expr, \&Modules::Karma::update);
}

sub get
{
	my $message = shift;

	my $name = $message->message;

	return unless $name;

	my $karma = 0;

	my $query = qq~
		SELECT name, karma
		FROM karma
		WHERE LOWER(name) = LOWER(?)
	~;
	my $user = db()->query($query, lc($name))->fetch;

	if ($user && $user->{'karma'}) {
		return "$name has karma of $user->{'karma'}";
	} else {
		return "$name has neutral karma";
	}
}

sub update
{
	my $message = shift;

	unless ($message->is_public) {
		return 'Karma updates must be done in public!';
	}

	# Parse message for name and direction
	my $name;
	my $direction;
	if ($message->message =~ $update_expr) {
		$name      = $1;
		$direction = $2;
	} else {
		return;
	}

	if (lc($message->from) eq lc($name)) {
		return "You can't change your own karma!";
	}

	# Check if entry already exists
	my $query = qq~
		SELECT name
		FROM karma
		WHERE name = ?
	~;
	my $karma = db()->query($query, lc($name))->fetch;

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
		db()->query($query, lc($name));
	} else {
		my $initial_value = ($direction eq '--' ? -1 : 1);
		$query = qq~
			INSERT INTO karma
			(name, karma)
			VALUES
			(?, ?)
		~;
		db()->query($query, lc($name), $initial_value);
	}
	return undef;
}

1;
