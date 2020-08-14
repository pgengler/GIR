package Modules::Infobot;

use strict;

use GIR::Message;

#######
## GLOBALS
#######
my @dunno = ("I don't know", 'Wish I knew', 'Beats me', 'I have no idea', "I think it's your mother");

my $feedbacked = 0;

my $force_learn_expr    = qr/^(.+)\s+\=(is|are)\=\>\s+(.+)$/;
my $learn_expr          = qr/^(.+?)\s+(is|are)\s+(.+)$/;
my $forget_expr         = qr/^forget\s+(.+)$/;
my $amend_expr          = qr/^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$/;
my $what_reply_expr     = qr/^(what\s*(\'s|is|are)*\s+)(.+?)\?*$/;
my $question_reply_expr = qr/^(.+)\?$/;
my $replace_expr        = qr/^no\,?\s+(($GIR::Bot::config->{'nick'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i;
my $append_expr         = qr/^(.+)\s+(is|are)\s+also\s+(.+)$/;

sub register
{
	GIR::Modules->register_action($force_learn_expr, \&process, 3); # learn() forcefully
	GIR::Modules->register_action($learn_expr, \&process); # learn()
	GIR::Modules->register_action($forget_expr, \&process); # forget()
	GIR::Modules->register_action($amend_expr, \&process); # amend()
	GIR::Modules->register_action($what_reply_expr, \&process, 2); # reply()
	GIR::Modules->register_action($question_reply_expr, \&process); # reply
	GIR::Modules->register_action($replace_expr, \&process, 2); # replace()
	GIR::Modules->register_action($append_expr, \&process, 2); # append()
	GIR::Modules->register_private('lock', \&lock); # lock()
	GIR::Modules->register_private('unlock', \&unlock); # unlock()
	GIR::Modules->register_action('literal', \&literal); # literal()

	GIR::Modules->register_listener(\&reply_listener, 4); # This is higher priority than the Math module listener for the amusing ability to set incorrect answers to math things

	GIR::Modules->register_event('mynickchange', \&nick_changed);

	GIR::Modules->register_help('infobot', \&help);
}

sub process
{
	my $message = shift;

	my $data = $message->message;

	# Figure out what we're doing
	if ($data =~ $force_learn_expr) {
		return learn($message, $1, $2, $3);
	} elsif ($data =~ /^no\,?\s+(($GIR::Bot::config->{'nick'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i) {
		my $msg;
		if ($1) {
			$msg = GIR::Message->new($message, { 'addressed' => 1 });
		} else {
			$msg = $message;
		}
		return replace($msg, $3, $4, $5);
	} elsif ($data =~ $append_expr) {
		return append($message, $1, $2, $3);
	} elsif ($data =~ $what_reply_expr) {
		return reply($message, $3);
	} elsif ($data =~ $learn_expr) {
		return learn($message, $1, $2, $3);
	} elsif ($data =~ $forget_expr) {
		return forget($message, $1);
	} elsif ($data =~ $amend_expr) {
		return amend($message, $1, $2, $3);
	} elsif ($data =~ $question_reply_expr) {
		return reply($message, $1);
	} else {
		GIR::Bot->debug("Infobot::process fell through somehow: message == %s", $data);
	}
}

sub learn
{
	my ($message, $phrase, $relates, $value) = @_;

	# Skip empty/all-whitespace $phrase values
	unless ($phrase =~ /\S/) {
		return;
	}

	# Check to see if we already have something matching this
	my $query = qq~
		SELECT phrase, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $result = db()->query($query, $phrase)->fetch;

	if ($result) {
		if ($message->is_explicit) {
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
		db()->query($query, $phrase, $relates, $value);

		GIR::Bot->status('LEARN: %s =%s=> %s', $phrase, $relates, $value);
	}

	if ($message->is_explicit) {
		return "OK, " . $message->from;
	} else {
		return 'NOREPLY';
	}
}

sub append
{
	my ($message, $phrase, $relates, $value) = @_;

	# Get current info
	my $query = qq~
		SELECT phrase, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $result = db()->query($query, $phrase)->fetch;

	if ($result) {
		# Make sure the item isn't locked
		if ($result->{'locked'}) {
			if ($message->is_explicit) {
				GIR::Bot->status('LOCKED: %s', $result->{'phrase'});
				return "I can't update that, " . $message->from;
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
		db()->query($query, $result->{'value'}, $result->{'phrase'});
	} else {
		if ($message->is_explicit) {
			return "I didn't have anything matching '$phrase', " . $message->from;
		}
	}

	if ($message->is_explicit) {
		return "OK, " . $message->from;
	}
	return 'NOREPLY';
}

sub forget
{
	my ($message, $what) = @_;

	# cut off final punctuation
	$what =~ s/[.!?]+$//;

	my ($found, $locked) = (0, 0);

	# Check if we have something matching this
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $statement = db()->query($query, $what);

	while (my $result = $statement->fetch) {
		if ($result->{'locked'}) {
			$locked = 1;
			GIR::Bot->status('LOCKED: %s', $result->{'phrase'});
		} else {
			$found = 1;

			# Remove
			$query = qq~
				DELETE FROM infobot
				WHERE LOWER(phrase) = LOWER(?)
			~;
			db()->query($query, $what);

			GIR::Bot->status('FORGET: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
		}
	}

	if ($found) {
		return $message->from . ": I forgot $what";
	} elsif ($locked) {
		if ($message->is_explicit) {
			return "I can't forget that, " . $message->from;
		} else {
			return 'NOREPLY';
		}
	} elsif ($message->is_explicit) {
		return $message->from . ", I didn't have anything matching $what";
	}
}

sub amend
{
	my ($message, $what, $replace, $with) = @_;

	my $rep_part = quotemeta($replace);

	# Look for initial value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	my $result = db()->query($query, $what)->fetch;

	unless ($result) {
		if ($message->is_explicit) {
			return "I don't have anything matching '$what', " . $message->from;
		} else {
			return 'NOREPLY';
		}
	}

	# Check if it's locked
	if ($result->{'locked'}) {
		if ($message->is_explicit) {
			GIR::Bot->status('LOCKED: %s', $result->{'phrase'});
			return "I can't update that, " . $message->from;
		} else {
			return 'NOREPLY';
		}
	}

	# Check that it matches
	unless ($result->{'value'} =~ /$rep_part/i) {
		if ($message->is_explicit) {
			return "That doesn't contain '$replace', " . $message->from;
		} else {
			return;
		}
	}

	GIR::Bot->status('OLD: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});

	# Replace
	$result->{'value'} =~ s/$rep_part/$with/i;

	GIR::Bot->status('NEW: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	db()->query($query, $result->{'value'}, $result->{'phrase'});

	if ($message->is_explicit) {
		return "OK, " . $message->from;
	}
}

sub replace
{
	my ($message, $what, $relates, $value) = @_;

	# Look up current value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $result = db()->query($query, $what)->fetch;

	unless ($result) {
		if ($message->is_explicit) {
			return "I don't have anything matching '$what', " . $message->from;
		} else {
			return 'NOREPLY';
		}
	}

	# Check if the item is locked
	if ($result->{'locked'}) {
		if ($message->is_explicit) {
			GIR::Bot->status('LOCKED: %s', $result->{'phrase'});
			return "I can't update that, " . $message->from;
		} else {
			return 'NOREPLY';
		}
	}

	GIR::Bot->status('WAS: %s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
	GIR::Bot->status('IS:  %s =%s=> %s', $result->{'phrase'}, $relates, $value);

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?,
			relates = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	db()->query($query, $value, $relates, $what);

	if ($message->is_explicit) {
		return "OK, " . $message->from;
	}
	return 'NOREPLY';
}

sub reply_listener
{
	my $message = shift;

	return undef unless $message->is_explicit;

	return reply($message, $message->message);
}

sub reply
{
	my ($message, $data) = @_;

	# Determine if this was likely something explicitly requested.
	# This means that it included the bot's name and ended in a question mark
	my $explicit = ($message->is_addressed && $data =~ /\?\s*$/);

	# Trim whitespace
	$data =~ s/^\s*(.+?)\s*$/$1/;

	# Take off any trailing punctuation
	$data =~ s/[\?|\!|\.|\,|\s*]+$//;

	# Ignore anything that wasn't explicitly requested and is too short
	if (exists($GIR::Bot::config->{'infobot_min_length'}) && !$explicit && length($data) < $GIR::Bot::config->{'infobot_min_length'}) {
		GIR::Bot->status("Skipping '%s' because it's too short", $data);
		return;
	}

	my ($phrase, $relates, $value, @params) = find_match($data);

	unless ($phrase) {
		if ($explicit) {
			return $dunno[int(rand(scalar(@dunno)))] . ', ' . $message->from;
		} else {
			return undef;
		}
	}

	GIR::Bot->status('FOUND: %s =%s=> %s', $phrase, $relates, $value);

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
		return parse_special($1, $message);
	} elsif ($value =~ /^\s*\<reply\>\s*$/) {
		return 'NOREPLY';
	} elsif ($value =~ /^\s*\<action\>\s*(.+)$/) {
		GIR::Bot->enqueue_action($message->where, parse_special($1, $message));
		return 'NOREPLY';
	} elsif ($value =~ /^\s*\<feedback\>\s*(.+)$/) {
		if (++$feedbacked > 2) {
			GIR::Bot->status('Feedback limit reached!');
			return undef;
		}

		my $msg = GIR::Message->new($message, {
			'message' => $1,
		});
		GIR::Modules->dispatch_t($msg);
		$feedbacked--;
		return 'NOREPLY';
	} elsif ($value =~ /^\s*(|.+?)\s*\<(.+?)\>\s*(.+)*$/) {
		# Feedback
		my ($extra, $action, $param) = ($1, $2, $3);

		GIR::Bot->debug("Modules::Infobot::reply: Feeding back action '%s' with extra info '%s' and pre-string '%s'", $action, $param, $extra);

		if (++$feedbacked > 2) {
			GIR::Bot->status('Feedback limit reached!');
			return undef;
		}

		my $data = $action;
		if ($param) {
			$data .= (' ' . $param);
		}

		my $result;

		my $msg = GIR::Message->new($message, {
			'message' => $data,
		});

		if ($extra) {
			$result = parse_special($extra) . ' ' . GIR::Modules->process($msg);
		} else {
			$result = GIR::Modules->process($msg);
		}
		$feedbacked--;

		return $result;
	} else {
		return "$phrase $relates " . parse_special($value, $message);
	}
}

sub find_match
{
	my ($data) = @_;

	return find_match_aux($data, ( ));
}

sub find_match_aux
{
	my ($data, @params) = @_;

	return undef unless $data;

	# Look for entry for this phrase
	GIR::Bot->debug("Modules::Infobot::find_match_aux: Looking for match for phrase '%s'", $data);
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	my $result = db()->query($query, $data)->fetch;

	if ($result) {
		# Make sure there's a suitable match
		my @parts = split(/\s*\|\s*/, $result->{'value'});
		if (scalar(@parts) > 1) {
			GIR::Bot->status("FOUND: %s [splitting into parts]", $result->{'value'});
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
				GIR::Bot->status('CHOSE: %s', $result->{'value'});
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

	return find_match_aux($data, @params);
}

sub lock
{
	my $message = shift;

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $message->message, 2);

	# Make sure the user can do that
	unless (Modules::Access::check_access($message->from, $password, 'lock')) {
		return "You don't have permission to do that, " . $message->from . '!';
	}

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $entry = db()->query($query, $phrase)->fetch;

	unless ($entry) {
		return "I don't have anything matching '$phrase', " . $message->from;
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = true
		WHERE LOWER(phrase) = LOWER(?)
	~;
	db()->query($query, $phrase);

	return "OK, " . $message->from;
}

sub unlock
{
	my $message = shift;

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $message->message, 2);

	# Make sure the user can do that
	unless (Modules::Access::check_access($message->from, $password, 'unlock')) {
		return "You don't have permission to do that, " . $message->from . '!';
	}

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $entry = db()->query($query, $phrase)->fetch;

	unless ($entry) {
		return "I don't have anything matching '$phrase', " . $message->from;
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = false
		WHERE LOWER(phrase) = LOWER(?)
	~;
	db()->query($query, $phrase);

	return "OK, " . $message->from;
}

sub literal
{
	my $message = shift;

	my $phrase  = $message->message;

	return undef unless $phrase;

	GIR::Bot->debug("Modules::Infobot::literal: Looking up literal value of '%s'", $phrase);

	# Look up this phrase
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	my $result = db()->query($query, $phrase)->fetch;

	if ($result) {
		return sprintf('%s =%s=> %s', $result->{'phrase'}, $result->{'relates'}, $result->{'value'});
	} else {
		# Not found; only reply if explicitly addressed publicly or privately
		if ($message->is_explicit) {
			return "I don't have anything matching '$phrase', " . $message->from;
		} else {
			return undef;
		}
	}
}


# Handle $who in string
sub parse_special
{
	my ($str, $message) = @_;

	return unless defined $str;

	my $user = $message->from;
	$str =~ s/\$who/$user/ig;
	$str =~ s/#{(.+?)}/feedback(GIR::Message->new($message, { 'message' => $1, 'addressed' => 1 }))/eg;

	return $str;
}

sub trim
{
	my $str = shift;

	return unless $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

sub nick_changed
{
	my $params = shift;

	# Rebuild regexp for replace handler to incorporate new nick
	GIR::Modules->unregister_action($replace_expr);
	$replace_expr = qr/^no\,?\s+(($params->{'new'})[,\s]\s*)?(.+?)\s+(is|are)\s+(.+)$/i;
	GIR::Modules->register_action($replace_expr, \&process, 2);
}

sub feedback
{
	my ($message) = @_;

	my $result = '';
	if ($feedbacked <= 2) {
		$feedbacked++;
		$result = GIR::Modules->process($message);
		$feedbacked--;
	}
	return $result;
}

sub help
{
	my $message = shift;

	my $str = "The Infobot module is used to store and retrieve facts and other information.\n";
	$str .= "I learn that x = y when someone says 'x is y' or 'x are y'. Then, when someone asks 'What is x?' or 'x?', I respond with 'x is y'\n";
	$str .= "You can say 'x is <reply>y' and I won't use the 'x is' part of a response.\n";
	$str .= "Multiple choices for 'x' can be separated with '|'. I'll choose one of the options to respond with.";

	return $str;
}

1;
