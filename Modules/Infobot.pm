package Modules::Infobot;

#######
## PERL SETUP
#######
use strict;
use lib ('./', '../Main');

#######
## INCLUDES
#######
use Database::MySQL;

#######
## GLOBALS
#######
my @dunno = ("I don't know", 'Wish I knew', 'Beats me', 'I have no idea', "I think it's your mother");

my $feedbacked = 0;

#######
## MAIN
#######
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

	&Modules::register_action('REGEXP:^(.+)\s+\=(is|are)\=\>\s+(.+)$', \&Modules::Infobot::process, 3); # learn() forcefully
	&Modules::register_action('REGEXP:^(.+)\s+(is|are)\s+(.+)$', \&Modules::Infobot::process); # learn()
	&Modules::register_action('REGEXP:^forget\s+(.+)$', \&Modules::Infobot::process); # forget()
	&Modules::register_action('REGEXP:^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$', \&Modules::Infobot::process); # amend()
	&Modules::register_action('REGEXP:^(what\s*[\'s|is|are]*\s+)(.+?)(\?)*$', \&Modules::Infobot::process); # reply()
	&Modules::register_action('REGEXP:^(.+)\?$', \&Modules::Infobot::process); # reply
	&Modules::register_action('REGEXP:^no\,?\s+(' . $Bot::config->{'nick'} . ')?\,?\s*(.+?)\s+(is|are)\s+(.+)$', \&Modules::Infobot::process); # replace()
	&Modules::register_action('REGEXP:^(.+)\s+(is|are)\s+also\s+(.+)$', \&Modules::Infobot::process); # append()
	&Modules::register_action('lock', \&Modules::Infobot::lock); # lock()
	&Modules::register_action('unlock', \&Modules::Infobot::unlock); # unlock()
	&Modules::register_action('literal', \&Modules::Infobot::literal); # literal()

	&Modules::register_listener(\&Modules::Infobot::reply_listener, 4); # This is higher priority than the Math module listener for the amusing ability to set incorrect answers to math things

	&Modules::register_help('infobot', \&Modules::Infobot::help);
}

sub process($)
{
	my $params  = shift;
	my $message = $params->{'message'};

	# Figure out what we're doing
	if ($message =~ /^(.+)\s+\=(is|are)\=\>\s+(.+)$/i) {
		return &learn($params, $1, $2, $3);
	} elsif ($message =~ /^no\,?\s+($Bot::config->{'nick'})?\,?\s*(.+?)\s+(is|are)\s+(.+)$/i) {
		if ($1) {
			$params->{'addressed'} = 1;
		}
		return &replace($params, $2, $3, $4);
	} elsif ($message =~ /^(what\s*[\'s|is|are]*\s+)(.+?)(\?)*$/i) {
		return &reply($params, $2);
	} elsif ($message =~ /^(.+)\?$/) {
		return &reply($params, $1);
	} elsif ($message =~ /^(.+)\s+(is|are)\s+also\s+(.+)$/i) {
		return &append($params, $1, $2, $3);
	} elsif ($message =~ /^(.+)\s+(is|are)\s+(.+)$/i) {
		return &learn($params, $1, $2, $3);
	} elsif ($message =~ /^forget\s+(.+)$/i) {
		return &forget($params, $1);
	} elsif ($message =~ /^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$/i) {
		return &amend($params, $1, $2, $3);
	} else {
		&Bot::status("Infobot::process fell through somehow: message == $message") if $Bot::config->{'debug'};
	}
}

sub learn($$$$)
{
	my ($params, $phrase, $relates, $value) = @_;

	# Skip empty/all-whitespace $phrase values
	unless ($phrase =~ /\S/) {
		return;
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Check to see if we already have something matching this
	my $query = qq~
		SELECT phrase, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $result = $sth->fetchrow_hashref();

	$sth->finish();

	if ($result && $result->{'phrase'}) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "... but $phrase $relates $result->{'value'}...";
		} else {
			return 'NOREPLY';
		}
	} else {
		$query = qq~
			INSERT INTO infobot
			(phrase, relates, value)
			VALUES
			(?, ?, ?)
		~;
		$db->prepare($query);
		$db->execute($phrase, $relates, $value);	

		&Bot::status("LEARN: $phrase =$relates=> $value");
	}

	if ($params->{'addressed'} || $params->{'type'} eq 'private') {
		return "OK, $params->{'user'}";
	} else {
		return 'NOREPLY';
	}
}

sub append($$$$)
{
	my ($params, $phrase, $relates, $value) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Get current info
	my $query = qq~
		SELECT phrase, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $result = $sth->fetchrow_hashref();

	$sth->finish();

	if ($result && $result->{'phrase'}) {
		# Make sure the item isn't locked
		if ($result->{'locked'}) {
			if ($params->{'addressed'} || $params->{'type'} eq 'private') {
				&Bot::status("LOCKED: $result->{'phrase'}");
				return "I can't update that, $params->{'user'}";
			} else {
				return 'NOREPLY';
			}
		}

		if ($value !~ /\s*\|/) {
			$result->{'value'} .= (' or ' . $value);
		} else {
			$result->{'value'} .= $value;
		}
		$result->{'value'} =~ s/\|\|/\|/g;

		$query = qq~
			UPDATE infobot SET
				value = ?
			WHERE LOWER(phrase) = LOWER(?)
		~;
		$db->prepare($query);
		$db->execute($result->{'value'}, $result->{'phrase'});
	} else {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "I didn't have anything matching '$phrase', $params->{'user'}";
		}
	}

	if ($params->{'addressed'} || $params->{'type'} eq 'private') {
		return "OK, $params->{'user'}";
	}
	return 'NOREPLY';
}

sub forget($$)
{
	my ($params, $what) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# cut off final punctuation
	$what =~ s/[.!?]+$//;

	my ($found, $locked) = (0, 0);

	# Check if we have something matching this
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);

	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'locked'}) {
			$locked = 1;
			&Bot::status("LOCKED: $result->{'phrase'}");
		} else {
			$found = 1;

			# Remove
			$query = qq~
				DELETE FROM infobot
				WHERE LOWER(phrase) = LOWER(?)
			~;
			$db->prepare($query);
			$db->execute($what);

			&Bot::status("FORGET: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");
		}
	}

	$sth->finish();

	if ($found) {
		return "$params->{'user'}: I forgot $what";
	} elsif ($locked) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "I can't forget that, $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	} elsif ($params->{'addressed'} || $params->{'type'} eq 'private') {
		return "$params->{'user'}, I didn't have anything matching $what";
	}
}

sub amend($$$$)
{
	my ($params, $what, $replace, $with) = @_;

	my $rep_part = quotemeta($replace);

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Look for initial value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "I don't have anything matching '$what', $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	}

	# Check if it's locked
	if ($result->{'locked'}) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			&Bot::status("LOCKED: $result->{'phrase'}");
			return "I can't update that, $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	}

	# Check that it matches
	unless ($result->{'value'} =~ /$rep_part/i) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "That doesn't contain '$replace', $params->{'user'}";
		} else {
			return;
		}
	}

	&Bot::status("OLD: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Replace
	$result->{'value'} =~ s/$rep_part/$with/i;

	&Bot::status("NEW: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($result->{'value'}, $result->{'phrase'});

	if ($params->{'addressed'} || $params->{'type'} eq 'private') {
		return "OK, $params->{'user'}";
	}
}

sub replace($$$$)
{
	my ($params, $what, $relates, $value) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Look up current value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "I don't have anything matching '$what', $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	}

	# Check if the item is locked
	if ($result->{'locked'}) {
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			&Bot::status("LOCKED: $result->{'phrase'}");
			return "I can't update that, $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	}

	&Bot::status("WAS: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");
	&Bot::status("IS:  $result->{'phrase'} =$relates=> $value");

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?,
			relates = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($value, $relates, $what);

	if ($params->{'addressed'} || $params->{'type'} eq 'private') {
		return "OK, $params->{'user'}";
	}
}

sub reply_listener($)
{
	my $params = shift;

	return &reply($params, $params->{'message'});
}

sub reply($$)
{
	my ($params, $data) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Determine if this was likely something explicitly requested.
	# This means that either the bot was addressed or the line ended with a question mark.
	my $explicit = ($params->{'addressed'} || $data =~ /\?\s*$/) ? 1 : 0;

	# Trim whitespace
	$data =~ s/^\s*(.+?)\s*$/$1/;

	# Take off any trailing punctuation
	$data =~ s/[\?|\!|\.|\,|\s*]+$//;

	# Ignore anything that wasn't explicitly requested and is too short
	if (exists($Bot::config->{'infobot_min_length'}) && !$explicit && length($data) < $Bot::config->{'infobot_min_length'}) {
		&Bot::status("Skipping '$data' because it's too short");
		return;
	}

	# Look for a match for the whole string
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	$db->prepare($query);
	my $sth = $db->execute($data);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if (defined($params->{'type'})) {
			return;
		} elsif ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return $dunno[int(rand(scalar(@dunno)))] . ", $params->{'user'}";
		} else {
			return 'NOREPLY';
		}
	}

	&Bot::status("FOUND: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Parse if we need to
	my @parts = split(/\|/, $result->{'value'});
	if (scalar(@parts) > 1) {
		$result->{'value'} = $parts[int(rand(scalar(@parts)))];
		&Bot::status("CHOSE: $result->{'value'}");
	}

	if ($result->{'value'} =~ /^\s*\<reply\>\s*(.+)$/) {
		return &parse_special($1, $params->{'user'});
	} elsif ($result->{'value'} =~ /^\s*\<reply\>\s*$/) {
		return 'NOREPLY';
	} elsif ($result->{'value'} =~ /^\s*\<action\>\s*(.+)$/) {
		&Bot::enqueue_action($params->{'where'}, &parse_special($1, $params->{'user'}));
		return 'NOREPLY';
	} elsif ($result->{'value'} =~ /^\s*\<feedback\>\s*(.+)$/) {
		if (++$feedbacked > 2) {
			&Bot::status("Feedback limit reached!");
			return undef;
		}
		local $params->{'message'} = $1;
		$sth->finish();
		$db->close();
		&Modules::dispatch_t($params);
		$feedbacked--;
		return 'NOREPLY';
	} elsif ($result->{'value'} =~ /^\s*(|.+?)\s*\<(.+?)\>\s*(.+)*$/) {
		# Feedback
		my ($extra, $action, $param) = ($1, $2, $3);

		&Bot::status(sprintf("Feeding back action '%s' with extra info '%s' and pre-string '%s'", $action, $param, $extra)) if $Bot::config->{'debug'};

		if (++$feedbacked > 2) {
			&Bot::status("Feedback limit reached!");
			return undef;
		}
		# Don't need to the DB any more
		$sth->finish();
		$db->close();

		my $data = $action;
		if ($param) {
			$data .= (' ' . $param);
		}

		my $result;

		if ($extra) {
			local $params->{'message'} = $data;
			$result = $extra . ' ' . &Modules::process($params);
			$feedbacked--;
		} else {
			local $params->{'message'} = $data;
			$result = &Modules::process($params);
			$feedbacked--;
		}
		return $result;
	} else {
		return "$result->{'phrase'} $result->{'relates'} " . &parse_special($result->{'value'}, $params->{'user'});
	}
}

sub lock($)
{
	my $params = shift;

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $params->{'message'}, 2);

	# Only handle this privately
	unless ($params->{'type'} eq 'private') {
		return 'NOREPLY';
	}

	# Make sure the user can do that
		unless (&Modules::Access::check_access($params->{'user'}, $password, 'lock')) {
		return "You don't have permission to do that, $params->{'user'}!";
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry && $entry->{'phrase'}) {
		return "I don't have anything matching '$phrase', $params->{'user'}";
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 1
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, $params->{'user'}";
}

sub unlock($)
{
	my $params = shift;

	# Only handle this privately
	unless ($params->{'type'} eq 'private') {
		return 'NOREPLY';
	}

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $params->{'message'}, 2);

	# Make sure the user can do that
	unless (&Modules::Access::check_access($params->{'user'}, $password, 'unlock')) {
		return "You don't have permission to do that, $params->{'user'}!";
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry && $entry->{'phrase'}) {
		return "I don't have anything matching '$phrase', $params->{'user'}";
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 0
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, $params->{'user'}";
}	

sub literal($)
{
	my $params = shift;
	my $data   = $params->{'message'};

	return undef unless $data;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Look up this phrase
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($data);
	my $result = $sth->fetchrow_hashref();

	if ($result && $result->{'phrase'}) {
		return sprintf('%s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
	} else {
		# Not found; only reply if explicitly addressed publicly or privately
		if ($params->{'addressed'} || $params->{'type'} eq 'private') {
			return "I don't have anything matching '$data', $params->{'user'}";
		} else {
			return undef;
		}
	}
}


# Handle $who in string
sub parse_special($$)
{
	my ($str, $user) = @_;

	return unless $str;

	$str =~ s/\$who/$user/ig;

	return $str;
}

sub trim($)
{
	my $str = shift;

	return unless $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

sub help($)
{
	my $params = shift;

	my $str = "The Infobot module is used to store and retrieve facts and other information.\n";
	$str .= "I learn that x = y when someone says 'x is y' or 'x are y'. Then, when someone asks 'What is x?' or 'x?', I respond with 'x is y'\n";
	$str .= "You can say 'x is <reply>y' and I won't use the 'x is' part of a response.\n";
	$str .= "Multiple choices for 'x' can be separated with '|'. I'll choose one of the options to respond with.";

	return $str;
}

1;
