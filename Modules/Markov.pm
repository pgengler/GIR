package Modules::Markov;

use strict;

sub register
{
	GIR::Modules->register_action('markov', \&Modules::Markov::output);
	GIR::Modules->register_action('markov2', \&Modules::Markov::output_multi);
	GIR::Modules->register_action('vokram', \&Modules::Markov::output_from_end);
	GIR::Modules->register_listener(\&Modules::Markov::learn, 1);
	GIR::Modules->register_listener(\&Modules::Markov::respond_if_addressed, 2);

	GIR::Modules->register_help('markov', \&Modules::Markov::help);
	GIR::Modules->register_help('markov2', \&Modules::Markov::help);
	GIR::Modules->register_help('vokram', \&Modules::Markov::help);
}

#######
## OUTPUT
#######
sub output
{
	my $message = shift;
	my $data    = $message->message;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = trim($1);
		$second = trim($2);
		GIR::Bot->debug("Modules::Markov::output: using '%s' and '%s'", $first, $second);
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = trim($1);
		GIR::Bot->debug("Modules::Markov::output: using '%s'", $first);
	}
	return gen_output($first, $second);
}

sub gen_output
{
	my ($first, $second) = @_;

	my $word;

	my $phrase = '';

	if ($first && $second) {
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY random()
			LIMIT 1
		~;
		$word = db()->query($query, $first, $second)->fetch;

		if ($word && $word->{'prev'}) {
			$phrase .= "$word->{'prev'} ";
		} else {
			return;
		}
	} elsif ($first) {
		# Find something starting with this
		my $query = qq~
			SELECT this, next
			FROM words
			WHERE this = ? AND next IS NOT NULL
			ORDER BY random()
			LIMIT 1
		~;
		$word = db()->query($query, $first)->fetch;

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		my $query = q[
			SELECT this, next
			FROM words
			WHERE prev IS NULL
			ORDER BY random()
			LIMIT 1
		];
		$word = db()->query($query)->fetch;
	}

	$phrase .= "$word->{'this'} ";
	unless ($word->{'next'}) {
		return $phrase;
	}

	my $query = qq~
		SELECT this, next
		FROM words
		WHERE prev = ? AND this = ?
		ORDER BY random()
		LIMIT 1
	~;
	my $statement = db()->statement($query);

	my $count = 0;
	while (1) {
		# Get next word
		$word = $statement->execute($word->{'this'}, $word->{'next'})->fetch;
		unless ($word && $word->{'this'}) {
			last;
		}

		$phrase .= "$word->{'this'} ";

		if (!$word->{'next'} || $count > 25) {
			last;
		}

		$count++;
	}
	return $phrase;
}

#######
## OUTPUT (FORWARD & BACKWARD)
#######
sub output_multi
{
	my $message = shift;
	my $data    = $message->message;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
	}
	return gen_output_multi($first, $second);
}

sub gen_output_multi
{
	my ($first, $second) = @_;

	my $word;

	my $phrase = '';

	if ($first && $second) {
		# First make sure the combo exists
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY random()
			LIMIT 1
		~;
		my $start = $word = db()->query($query, $first, $second)->fetch;

		$phrase  = $word->{'this'};

		# Work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY random()
			LIMIT 1
		~;
		my $statement = db()->statement($query);

		while ($word && $word->{'prev'}) {
			$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY random()
		~;
		$statement = db()->statement($query);

		$word = $start;
		while ($word && $word->{'next'}) {
			$word = $statement->execute($word->{'this'}, $word->{'next'})->fetch;
			$phrase = "$phrase $word->{'this'}";
		}
	} elsif ($first) {
		# Find something starting with this
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ?
			ORDER BY random()
			LIMIT 1
		~;
		my $start = $word = db()->query($query, $first)->fetch;

		$phrase  = $word->{'this'};

		# First work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY random()
		~;
		my $statement = db()->statement($query);

		while ($word && $word->{'prev'}) {
			$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY random()
		~;
		$statement = db()->statement($query);

		$word = $start;
		while ($word && $word->{'next'}) {
			$word = $statement->execute($word->{'this'}, $word->{'next'})->fetch;
			$phrase = "$phrase $word->{'this'}";
		}
	} else {
		$phrase = gen_output();
	}
	return $phrase;
}

#######
## OUTPUT FROM END
#######
sub output_from_end
{
	my $message = shift;
	my $data    = $message->message;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
	}
	return gen_output_from_end($first, $second);
}

sub gen_output_from_end
{
	my ($first, $second) = @_;
	my $word;

	my $phrase = '';

	my $query;

	if ($first && $second) {
		$query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY random()
			LIMIT 1
		~;
		$word = db()->query($query, $first, $second)->fetch;

		if ($word && $word->{'next'}) {
			$phrase .= "$word->{'next'} ";
		} else {
			return;
		}
	} elsif ($first) {
		# Find something ending with this
		$query = qq~
			SELECT prev, this
			FROM words
			WHERE this = ? AND next IS NULL
			ORDER BY random()
			LIMIT 1
		~;
		$word = db()->query($query, $first)->fetch;

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		my $query = q[
			SELECT prev, this
			FROM words
			WHERE next IS NULL
			ORDER BY random()
			LIMIT 1
		];
		$word = db()->query($query)->fetch;
	}

	$phrase = "$word->{'this'} $phrase";
	unless ($word->{'prev'}) {
		return $phrase;
	}

	$query = qq~
		SELECT prev, this
		FROM words
		WHERE this = ? AND next = ?
		ORDER BY random()
		LIMIT 1
	~;
	my $statement = db()->statement($query);

	my $count = 0;
	do {
		# Get next word
		$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
		unless ($word && $word->{'this'}) {
			last;
		}

		$phrase = "$word->{'this'} $phrase";

	} while ($word && $word->{'prev'} && $count++ <= 25);
	return $phrase;
}

#######
## LEARN
#######
sub learn
{
	my $message = shift;
	my $data    = $message->message;

	return if should_ignore($message->from);

	my @parts = split(/\s+/, $data);

	return if scalar(@parts) == 0;

	unshift @parts, undef;
	push @parts, undef;

	my $lookup_sql = q(
		SELECT prev, this, next
		FROM words
		WHERE COALESCE(prev, '__BEGIN__') = LEFT(COALESCE(?, '__BEGIN__'), 255) AND this = LEFT(?, 255) AND COALESCE(next, '__END__') = LEFT(COALESCE(?, '__END__'), 255)
	);
	my $lookup = db()->statement($lookup_sql);

	my $insert_sql = q(
		INSERT INTO words
		(prev, this, next)
		VALUES
		(?, ?, ?)
	);
	my $insert = db()->statement($insert_sql);

	for (my $i = 1; $i < scalar(@parts) - 1; $i++) {
		my $word = $lookup->execute($parts[$i - 1], $parts[$i], $parts[$i + 1])->fetch;

		unless ($word && ($word->{'prev'} || $word->{'this'} || $word->{'next'})) {
			$insert->execute($parts[$i - 1], $parts[$i], $parts[$i + 1]);
		}
	}
}

#######
## RESPOND IF ADDRESSED
#######
## If no other module handled this message and the bot was addressed, generate
## a response using markov stuff.
#######
sub respond_if_addressed
{
	my $message = shift;
	my $data    = $message->message;

	return unless $message->is_explicit;

	# Based on random numbers, decide which markov method to use and which word(s) to seed with

	my @words = split(/\s+/, $data);

	my $msg;

	if (scalar(@words) >= 2) {
		# First figure out which action to take
		my $r = rand();
		if ($r < .4) { # normal markov
			# Now figure out which word(s) to use
			$r = rand();
			if ($r < .2) {
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s' and '%s'", $words[0], $words[1]);
				# Use first two words
				$msg = gen_output($words[0], $words[1]);
			} elsif ($r < .4) {
				# Pick random word and its follower
				$r = int(rand(scalar(@words) - 1));
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s' and '%s'", $words[ $r ], $words[ $r + 1 ]);
				$msg = gen_output($words[$r], $words[$r + 1]);
			} elsif ($r < .6) {
				# Pick first word
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[0]);
				$msg = gen_output($words[0]);
			} elsif ($r < .8) {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[ $r ]);
				$msg = gen_output($words[$r]);
			} else {
				# No word
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from random word");
				$msg = gen_output();
			}
		} elsif ($r < .8) { # bidirectional markov
			# Now figure out which word(s) to use
			$r = rand();
			if ($r < .25) {
				# Use first two words
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s' and '%s'", $words[0], $words[1]);
				$msg = gen_output_multi($words[0], $words[1]);
			} elsif ($r < .5) {
				# Pick random word and its follower
				$r = int(rand(scalar(@words) - 1));
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s' and '%s'", $words[ $r ], $words[ $r + 1 ]);
				$msg = gen_output_multi($words[$r], $words[$r + 1]);
			} elsif ($r < .75) {
				# Use first word
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[0]);
				$msg = gen_output_multi($words[0]);
			} else {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[ $r ]);
				$msg = gen_output_multi($words[$r]);
			}
		} else { # reverse markov
			# Now figure out which word(s) to use
			my $r = rand();
			if ($r < .3333) {
				# Use last two words
				my $n = scalar(@words) - 1;
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s' and '%s'", $words[ $n - 1 ], $words[ $n ]);
				$msg = gen_output_from_end($words[$n - 1], $words[$n]);
			} elsif ($r < .66666) {
				# Use last word
				my $n = scalar(@words) - 1;
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s'", $words[ $n ]);
				$msg = gen_output_from_end($words[$n]);
			} else {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s'", $words[ $r ]);
				$msg = gen_output_from_end($words[$r]);
			}
		}
	} else {
		if (rand() < .5) {
			if (rand() < .5) {
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[0]);
				$msg = gen_output($words[0]);
			} else {
				GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[0]);
				$msg = gen_output_multi($words[0]);
			}
		} else {
			GIR::Bot->debug("Modules::Markov::respond_if_addressed: Generating markov response from random word");
			$msg = gen_output();
		}
	}
	return $msg;
}

#######
## HELP
#######
sub help
{
	my $message = shift;

	if ($message->message eq 'markov') {
		return "'markov [<word> [<word>]]': create and print a Markov chain starting with the given word(s). At most two words can be used to start the chain. See also 'markov2' and 'vokram'";
	} elsif ($message->message eq 'markov2') {
		return "'markov2 <word> [<word>]': create and print a Markov chain containing the given word(s). This can appear anywhere in the chain, not just at the beginning. See also 'markov' and 'vokram'";
	} elsif ($message->message eq 'vokram') {
		return "'vokram <word> [<word>]': create and print a Markov chain that ends with the given word(s). At most two words can be used as the basis for the chain. See also 'markov' and 'markov2'";
	}
}

##############

sub should_ignore
{
	my ($nick) = @_;

	my $nicks_to_ignore = config('ignore') || [ ];

	GIR::Bot->debug("Modules::Markov: checking whether to ignore '%s': %s", $nick, ($nick ~~ $nicks_to_ignore) ? 'yes' : 'no');

	return ($nick ~~ $nicks_to_ignore);
}

sub trim
{
	my $str = shift;

	return unless $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

1;
