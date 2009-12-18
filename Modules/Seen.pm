package Modules::Seen;

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

	&Modules::register_action('seen', \&Modules::Seen::seen);
	&Modules::register_listener(\&Modules::Seen::update, 'always');

	&Modules::register_help('seen', \&Modules::Seen::help);
}

sub seen()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	$data =~ s/^\s*(.+?)\s*$/$1/;

	my $nick = lc($data);

	# Check if we've seen this person
	my $query = qq~
		SELECT who, what, `where`, `when`
		FROM seen
		WHERE who = ?
	~;
	$db->prepare($query);
	my $sth = $db->execute($nick);
	my $seen = $sth->fetchrow_hashref();

	if ($seen) {
		my $howlong = time() - $seen->{'when'};
		$seen->{'when'} = localtime($seen->{'when'});

		my $tstring = ($howlong % 60) . " seconds ago";
		$howlong = int($howlong / 60);

		if ($howlong % 60) {
			$tstring = ($howlong % 60) . " minutes and $tstring";
		}
		$howlong = int($howlong / 60);

		if ($howlong % 24) {
			$tstring = ($howlong % 24) . " hours, $tstring";
		}
		$howlong = int($howlong / 24);

		if ($howlong % 365) {
			$tstring = ($howlong % 365) . " days, $tstring";
		}
		$howlong = int($howlong / 365);

		if ($howlong > 0) {
			$tstring = "$howlong years, $tstring";
		}

		return "$data was last seen on $seen->{'where'} $tstring, saying: $seen->{'what'} [$seen->{'when'}]";
	} else {
		return "I haven't seen '$data', $user";
	}
}

sub update()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	if ($type eq 'private') {
		$where = 'a private message';
		$data = '<private>';
	}

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Check to see if we have an entry for this user
	my $query = qq~
		SELECT who
		FROM seen
		WHERE who = ?
	~;
	$db->prepare($query);
	my $sth = $db->execute(lc($user));
	my $seen = $sth->fetchrow_hashref();

	if ($seen && $seen->{'who'}) {
		$query = qq~
			UPDATE seen SET
				`where` = ?,
				what = ?,
				`when` = ?
			WHERE who = ?
		~;
		$db->prepare($query);
		$db->execute($where, $data, time(), lc($user));
	} else {
		$query = qq~
			INSERT INTO seen
			(who, what, `where`, `when`)
			VALUES
			(?, ?, ?, ?)
		~;
		$db->prepare($query);
		$db->execute(lc($user), $data, $where, time());
	}
	return undef;
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'seen <user>': displays information about the last time <user> spoke when I was around.";
}

1;
