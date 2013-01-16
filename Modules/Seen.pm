package Modules::Seen;

use strict;
use lib ('./', '../lib');

use Util;

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

	Modules::register_action('seen', \&Modules::Seen::seen);
	Modules::register_listener(\&Modules::Seen::update, -1);

	Modules::register_help('seen', \&Modules::Seen::help);
}

sub seen($)
{
	my $message = shift;

	my $nick    = $message->message();

	# Remove leading/trailing whitespace
	$nick =~ s/^\s*(.+?)\s*$/$1/;

	return unless $nick;

	$nick = lc($nick);

	# Check if we've seen this person
	my $query = qq~
		SELECT who, what, `where`, UNIX_TIMESTAMP(`when`) AS `when`
		FROM seen
		WHERE who = ?
	~;
	my $seen = db->query($query, $nick)->fetch;

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

		return "$nick was last seen on $seen->{'where'} $tstring, saying: $seen->{'what'} [$seen->{'when'}]";
	} else {
		return "I haven't seen '$nick', " . $message->from();
	}
}

sub update($)
{
	my $message = shift;

	my $where = $message->where();
	my $data  = $message->raw();

	unless ($message->is_public()) {
		$where = 'a private message';
		$data = '<private>';
	}

	# Check to see if we have an entry for this user
	my $query = qq~
		SELECT who
		FROM seen
		WHERE who = ?
	~;
	my $seen = db->query($query, lc($message->from))->fetch;

	if ($seen && $seen->{'who'}) {
		$query = qq~
			UPDATE seen SET
				`where` = ?,
				what = ?,
				`when` = NOW()
			WHERE who = ?
		~;
		db->query($query, $where, $data, lc($message->from));
	} else {
		$query = qq~
			INSERT INTO seen
			(who, what, `where`, `when`)
			VALUES
			(?, ?, ?, NOW())
		~;
		db->query($query, lc($message->from), $data, $where);
	}
	return undef;
}

sub help($)
{
	my $message = shift;

	return "'seen <user>': displays information about the last time <user> spoke when I was around.";
}

1;
