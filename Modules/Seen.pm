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
	&Modules::register_listener(\&Modules::Seen::update, -1);

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

		my $tstring = ' ago';

		my $seconds = $howlong % 60;
		if ($seconds == 1) {
			$tstring = "1 second" . $tstring;
		} else {
			$tstring = "$seconds seconds" . $tstring;
		}
		$howlong = int($howlong / 60);

		my $minutes = $howlong % 60;
		if ($minutes == 1) {
			$tstring = "1 minute and " . $tstring;
		} elsif ($minutes) {
			$tstring = "$minutes minutes and " . $tstring;
		}
		$howlong = int($howlong / 60);

		my $hours = $howlong % 24;
		if ($hours == 1) {
			$tstring = '1 hour, ' . $tstring;
		} elsif ($hours) {
			$tstring = "$hours hours, " . $tstring;
		}
		$howlong = int($howlong / 24);

		my $days = $howlong % 365;
		if ($days == 1) {
			$tstring = '1 day, ' . $tstring;
		} elsif ($days) {
			$tstring = "$days days, " . $tstring;
		}
		$howlong = int($howlong / 365);

		if ($howlong == 1) {
			$tstring = '1 year, ' . $tstring;
		} elsif ($howlong) {
			$tstring = "$howlong years, " . $tstring;
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
