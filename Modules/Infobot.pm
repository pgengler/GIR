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
use Message;

#######
## GLOBALS
#######
my @dunno = ("I don't know", 'Wish I knew', 'Beats me', 'I have no idea', "I think it's your mother");

my $feedbacked = 0;

my $force_learn_expr    = qr/^(.+)\s+\=(is|are)\=\>\s+(.+)$/;
my $learn_expr          = qr/^(.+)\s+(is|are)\s+(.+)$/;
my $forget_expr         = qr/^forget\s+(.+)$/;
my $amend_expr          = qr/^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$/;
my $what_reply_expr     = qr/^(what\s*(\'s|is|are)*\s+)(.+?)\?*$/;
my $question_reply_expr = qr/^(.+)\?$/;
my $replace_expr        = qr/^no\,?\s+(($Bot::config->{'nick'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i;
my $append_expr         = qr/^(.+)\s+(is|are)\s+also\s+(.+)$/;

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

	&Modules::register_action($force_learn_expr, \&Modules::Infobot::process, 3); # learn() forcefully
	&Modules::register_action($learn_expr, \&Modules::Infobot::process); # learn()
	&Modules::register_action($forget_expr, \&Modules::Infobot::process); # forget()
	&Modules::register_action($amend_expr, \&Modules::Infobot::process); # amend()
	&Modules::register_action($what_reply_expr, \&Modules::Infobot::process, 2); # reply()
	&Modules::register_action($question_reply_expr, \&Modules::Infobot::process); # reply
	&Modules::register_action($replace_expr, \&Modules::Infobot::process, 2); # replace()
	&Modules::register_action($append_expr, \&Modules::Infobot::process, 2); # append()
	&Modules::register_action('lock', \&Modules::Infobot::lock); # lock()
	&Modules::register_action('unlock', \&Modules::Infobot::unlock); # unlock()
	&Modules::register_action('literal', \&Modules::Infobot::literal); # literal()

	&Modules::register_listener(\&Modules::Infobot::reply_listener, 4); # This is higher priority than the Math module listener for the amusing ability to set incorrect answers to math things

	&Modules::register_nickchange(\&Modules::Infobot::nick_changed);

	&Modules::register_help('infobot', \&Modules::Infobot::help);
}

sub process($)
{
	my $message = shift;

	my $data = $message->message();

	# Figure out what we're doing
	if ($data =~ $force_learn_expr) {
		return &learn($message, $1, $2, $3);
	} elsif ($data =~ /^no\,?\s+(($Bot::config->{'nick'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i) {
		my $msg;
		if ($1) {
			$msg = new Message($message, { 'addressed' => 1 });
		} else {
			$msg = $message;
		}
		return &replace($msg, $3, $4, $5);
	} elsif ($data =~ $append_expr) {
		return &append($message, $1, $2, $3);
	} elsif ($data =~ $what_reply_expr) {
		return &reply($message, $3);
	} elsif ($data =~ $learn_expr) {
		return &learn($message, $1, $2, $3);
	} elsif ($data =~ $forget_expr) {
		return &forget($message, $1);
	} elsif ($data =~ $amend_expr) {
		return &amend($message, $1, $2, $3);
	} elsif ($data =~ $question_reply_expr) {
		return &reply($message, $1);
	} else {
		Bot::debug("Infobot::process fell through somehow: message == %s", $data);
	}
}

sub learn($$$$)
{
	my ($message, $phrase, $relates, $value) = @_;

	# Skip empty/all-whitespace $phrase values
	unless ($phrase =~ /\S/) {
		return;
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

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

	if ($result) {
		if ($message->is_explicit()) {
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

		Bot::status('LEARN: %s =%s=> %s', $phrase, $relates, $value);
	}

	if ($message->is_explicit()) {
		return "OK, " . $message->from();
	} else {
		return 'NOREPLY';
	}
}

sub append($$$$)
{
	my ($message, $phrase, $relates, $value) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

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

	if ($result) {
		# Make sure the item isn't locked
		if ($result->{'locked'}) {
			if ($message->is_explicit()) {
				Bot::status('LOCKED: %s', $result->{'phrase'});
				return "I can't update that, " . $message->from();
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
		if ($message->is_explicit()) {
			return "I didn't have anything matching '$phrase', " . $message->from();
		}
	}

	if ($message->is_explicit()) {
		return "OK, " . $message->from();
	}
	return 'NOREPLY';
}

sub forget($$)
{
	my ($message, $what) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

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
			Bot::status('LOCKED: %s', $result->{'phrase'});
		} else {
			$found = 1;

			# Remove
			$query = qq~
				DELETE FROM infobot
				WHERE LOWER(phrase) = LOWER(?)
			~;
			$db->prepare($query);
			$db->execute($what);

			Bot::status('FORGET: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
		}
	}

	$sth->finish();

	if ($found) {
		return $message->from() . ": I forgot $what";
	} elsif ($locked) {
		if ($message->is_explicit()) {
			return "I can't forget that, " . $message->from();
		} else {
			return 'NOREPLY';
		}
	} elsif ($message->is_explicit()) {
		return $message->from() . ", I didn't have anything matching $what";
	}
}

sub amend($$$$)
{
	my ($message, $what, $replace, $with) = @_;

	my $rep_part = quotemeta($replace);

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

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

	unless ($result) {
		if ($message->is_explicit()) {
			return "I don't have anything matching '$what', " . $message->from();
		} else {
			return 'NOREPLY';
		}
	}

	# Check if it's locked
	if ($result->{'locked'}) {
		if ($message->is_explicit()) {
			Bot::status('LOCKED: %s', $result->{'phrase'});
			return "I can't update that, " . $message->from();
		} else {
			return 'NOREPLY';
		}
	}

	# Check that it matches
	unless ($result->{'value'} =~ /$rep_part/i) {
		if ($message->is_explicit()) {
			return "That doesn't contain '$replace', " . $message->from();
		} else {
			return;
		}
	}

	Bot::status('OLD: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});

	# Replace
	$result->{'value'} =~ s/$rep_part/$with/i;

	Bot::status('NEW: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($result->{'value'}, $result->{'phrase'});

	if ($message->is_explicit()) {
		return "OK, " . $message->from();
	}
}

sub replace($$$$)
{
	my ($message, $what, $relates, $value) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	# Look up current value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);
	my $result = $sth->fetchrow_hashref();

	unless ($result) {
		if ($message->is_explicit()) {
			return "I don't have anything matching '$what', " . $message->from();
		} else {
			return 'NOREPLY';
		}
	}

	# Check if the item is locked
	if ($result->{'locked'}) {
		if ($message->is_explicit()) {
			Bot::status('LOCKED: %s', $result->{'phrase'});
			return "I can't update that, " . $message->from();
		} else {
			return 'NOREPLY';
		}
	}

	Bot::status('WAS: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
	Bot::status('IS:  %s =%s=> %s', $result->{'phrase'}, $relates, $value);

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?,
			relates = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($value, $relates, $what);

	if ($message->is_explicit()) {
		return "OK, " . $message->from();
	}
	return 'NOREPLY';
}

sub reply_listener($)
{
	my $message = shift;

	return &reply($message, $message->message());
}

sub reply($$)
{
	my ($message, $data) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	# Determine if this was likely something explicitly requested.
	# This means that it included the bot's name and ended in a question mark
	my $explicit = ($message->is_addressed() && $data =~ /\?\s*$/);

	# Trim whitespace
	$data =~ s/^\s*(.+?)\s*$/$1/;

	# Take off any trailing punctuation
	$data =~ s/[\?|\!|\.|\,|\s*]+$//;

	# Ignore anything that wasn't explicitly requested and is too short
	if (exists($Bot::config->{'infobot_min_length'}) && !$explicit && length($data) < $Bot::config->{'infobot_min_length'}) {
		Bot::status("Skipping '%s' because it's too short", $data);
		return;
	}

	my ($phrase, $relates, $value, @params) = &find_match($db, $data);

	unless ($phrase) {
		if ($explicit) {
			return $dunno[int(rand(scalar(@dunno)))] . ', ' . $message->from();
		} else {
			return undef;
		}
	}

	Bot::status('FOUND: %s =%s=> %s', $phrase, $relates, $value);

	# Replace param placeholders with values
	my $max_param_used = 0;
	for my $i (0..$#params) {
		my $j = $i + 1;
		my $param = $params[$i];
		if ($value =~ s/\$($j)\$/$param/g) {
			$max_param_used = $1;
		}
	}
	if ($max_param_used < scalar(@params) && $value =~ /\$\@\$/) {
		my $remainder = join(' ', @params[$max_param_used..$#params]);
		$value =~ s/\$\@\$/$remainder/g;
	}

	# Parse if we need to
	if ($value =~ /^\s*\<reply\>\s*(\S.*)$/) {
		return &parse_special($1, $message->from());
	} elsif ($value =~ /^\s*\<reply\>\s*$/) {
		return 'NOREPLY';
	} elsif ($value =~ /^\s*\<action\>\s*(.+)$/) {
		&Bot::enqueue_action($message->where(), &parse_special($1, $message->from()));
		return 'NOREPLY';
	} elsif ($value =~ /^\s*\<feedback\>\s*(.+)$/) {
		if (++$feedbacked > 2) {
			Bot::status('Feedback limit reached!');
			return undef;
		}

		$db->close();

		my $msg = new Message($message, {
			'message' => $1,
		});
		&Modules::dispatch_t($msg);
		$feedbacked--;
		return 'NOREPLY';
	} elsif ($value =~ /^\s*(|.+?)\s*\<(.+?)\>\s*(.+)*$/) {
		# Feedback
		my ($extra, $action, $param) = ($1, $2, $3);

		Bot::debug("Modules::Infobot::reply: Feeding back action '%s' with extra info '%s' and pre-string '%s'", $action, $param, $extra);

		if (++$feedbacked > 2) {
			Bot::status('Feedback limit reached!');
			return undef;
		}

		my $data = $action;
		if ($param) {
			$data .= (' ' . $param);
		}

		my $result;

		$db->close();

		my $msg = new Message($message, {
			'message' => $data,
		});

		if ($extra) {
			$result = $extra . ' ' . &Modules::process($msg);
		} else {
			$result = &Modules::process($msg);
		}
		$feedbacked--;

		return $result;
	} else {
		return "$phrase $relates " . &parse_special($value, $message->from());
	}
}

sub find_match($$)
{
	my ($db, $data) = @_;

	return &find_match_aux($db, $data, ( ));	
}

sub find_match_aux($$@)
{
	my ($db, $data, @params) = @_;

	return undef unless $data;

	# Look for entry for this phrase
	Bot::debug("Modules::Infobot::find_match_aux: Looking for match for phrase '%s'", $data);
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	$db->prepare($query);
	my $sth = $db->execute($data);
	my $result = $sth->fetchrow_hashref();
	$sth->finish();

	if ($result) {
		# Make sure there's a suitable match
		my @parts = split(/\s*\|\s*/, $result->{'value'});
		if (scalar(@parts) > 1) {
			Bot::status("FOUND: %s [splitting into parts]", $result->{'value'});
			my $have_params = scalar(@params);
			# Keep only parts that don't require more parameters than are available
			@parts = grep {
				my $part = $_;
				my $need_params = 0;
				my $eat_extra   = 0;
				for my $i (1..9) {
					$need_params = $i if $part =~ /\$$i\$/;
				}
				$eat_extra = 1 if $part =~ /\$\@\$/;
				(
					($need_params == 0 && $have_params == 0) # no parameters in part and none provided
					||
					(
						$need_params > 0 # one or more parameters in part
						&&
						(
							(!$eat_extra && $need_params == $have_params) # all parameters are explicit and the number required matches the number given
							||
							($eat_extra && $need_params < $have_params)   # catchall param included and number of explicit params is at least one less than number of given params
						)
					)
				);
			} @parts;

			if (scalar(@parts) > 0) {
				$result->{'value'} = $parts[int(rand(scalar(@parts)))];
				Bot::status('CHOSE: %s', $result->{'value'});
			} else {
				return undef;
			}
		} else {
			# Figure out how many params are required and available
			my $have_params = scalar(@params);
			my $need_params = 0;
			my $eat_extra   = 1 if $result->{'value'} =~ /\$\@\$/;

			for my $i (1..9) {
				$need_params = $i if $result->{'value'} =~ /\$$i\$/;
			}

			# Make sure string fits parameters
			unless (
				($need_params == 0 && $have_params == 0) # no parameters in part and none provided
				||
				(
					$need_params > 0 # one or more parameters in part
					&&
					(
						(!$eat_extra && $need_params == $have_params) # all parameters are explicit and the number required matches the number given
						||
						($eat_extra && $need_params < $have_params)   # catchall param included and number of explicit params is at least one less than number of given params
					)
				)
			) {
				return undef;
			}
		}

		return ($result->{'phrase'}, $result->{'relates'}, $result->{'value'}, @params);
	}

	# Remove last word from phrase and add to head of @params
	if ($data =~ /^(.+)\s+(.+?)$/) {
		$data =~ s/^(.+)\s+(.+?)$/$1/;
		unshift @params, $2;
	} else {
		return undef;
	}

	return &find_match_aux($db, $data, @params);
}

sub lock($)
{
	my $message = shift;

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $message->message(), 2);

	# Only handle this privately
	return 'NOREPLY' if $message->is_public();

	# Make sure the user can do that
	unless (&Modules::Access::check_access($message->from(), $password, 'lock')) {
		return "You don't have permission to do that, " . $message->from() . '!';
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry) {
		return "I don't have anything matching '$phrase', " . $message->from();
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 1
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, " . $message->from();
}

sub unlock($)
{
	my $message = shift;

	# Only handle this privately
	return 'NOREPLY' if $message->is_public();

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $message->message(), 2);

	# Make sure the user can do that
	unless (&Modules::Access::check_access($message->from(), $password, 'unlock')) {
		return "You don't have permission to do that, " . $message->from() . '!';
	}

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry) {
		return "I don't have anything matching '$phrase', " . $message->from();
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 0
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, " . $message->from();
}	

sub literal($)
{
	my $message = shift;

	my $phrase  = $message->message();

	return undef unless $phrase;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	Bot::debug("Modules::Infobot::literal: Looking up literal value of '%s'", $phrase);

	# Look up this phrase
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);
	my $result = $sth->fetchrow_hashref();

	if ($result) {
		return sprintf('%s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
	} else {
		# Not found; only reply if explicitly addressed publicly or privately
		if ($message->is_explicit()) {
			return "I don't have anything matching '$phrase', " . $message->from();
		} else {
			return undef;
		}
	}
}


# Handle $who in string
sub parse_special($$)
{
	my ($str, $user) = @_;

	return unless defined $str;

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

sub nick_changed($)
{
	my $params = shift;

	# Rebuild regexp for replace handler to incorporate new nick
	&Modules::unregister_action($replace_expr);
	$replace_expr = qr/^no\,?\s+(($params->{'new'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i;
	&Modules::register_action($replace_expr, \&Modules::Infobot::process, 2);
}

sub help($)
{
	my $message = shift;

	my $str = "The Infobot module is used to store and retrieve facts and other information.\n";
	$str .= "I learn that x = y when someone says 'x is y' or 'x are y'. Then, when someone asks 'What is x?' or 'x?', I respond with 'x is y'\n";
	$str .= "You can say 'x is <reply>y' and I won't use the 'x is' part of a response.\n";
	$str .= "Multiple choices for 'x' can be separated with '|'. I'll choose one of the options to respond with.";

	return $str;
}

1;
