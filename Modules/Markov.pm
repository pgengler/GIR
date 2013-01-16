package Modules::Markov;

use strict;
use lib ('./', '../lib');

use GIR::Util;

##############
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

	GIR::Modules::register_action('markov', \&Modules::Markov::output);
	GIR::Modules::register_action('markov2', \&Modules::Markov::output_multi);
	GIR::Modules::register_action('vokram', \&Modules::Markov::output_from_end);
	GIR::Modules::register_listener(\&Modules::Markov::learn, 1);
	GIR::Modules::register_listener(\&Modules::Markov::respond_if_addressed, 2);

	GIR::Modules::register_help('markov', \&Modules::Markov::help);
	GIR::Modules::register_help('markov2', \&Modules::Markov::help);
	GIR::Modules::register_help('vokram', \&Modules::Markov::help);
}

#######
## OUTPUT
#######
sub output($)
{
	my $message = shift;
	my $data    = $message->message();

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
		GIR::Bot::debug("Modules::Markov::output: using '%s' and '%s'", $first, $second);
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
		GIR::Bot::debug("Modules::Markov::output: using '%s'", $first);
	}
	return gen_output($first, $second);
}

sub gen_output(;$$)
{
	my ($first, $second) = @_;

	my $word;

	my $phrase = '';

	if ($first && $second) {
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		$word = db->query($query, $first, $second)->fetch;

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
			WHERE this = ? AND next <> '__END__'
			ORDER BY RAND()
			LIMIT 1
		~;
		$word = db->query($query, $first)->fetch;

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		## First, get count of rows
		my $query = qq~
			SELECT COUNT(*) AS count
			FROM words
			WHERE prev = '__BEGIN__'
		~;
		my $count = db->query($query)->fetch('count');

		## Now pick a random number between 0 and $count - 1
		my $row = int(rand($count));

		## Now get the $row-th row
		$query = qq~
			SELECT this, next
			FROM words
			WHERE prev = '__BEGIN__'
			LIMIT $row, 1
		~;
		$word = db->query($query)->fetch;
	}

	$phrase .= "$word->{'this'} ";
	if ($word->{'next'} eq '__END__') {
		return $phrase;
	}

	my $query = qq~
		SELECT this, next
		FROM words
		WHERE prev = ? AND this = ?
		ORDER BY RAND() DESC
		LIMIT 1
	~;
	my $statement = db->statement($query);

	my $count = 0;
	while (1) {
		# Get next word
		my $word = $statement->execute($word->{'this'}, $word->{'next'})->fetch;

		unless ($word && $word->{'this'}) {
			last;
		}

		$phrase .= "$word->{'this'} ";

		if ($word->{'next'} eq '__END__' || $count > 25) {
			last;
		}

		$count++;
	}
	return $phrase;
}

#######
## OUTPUT (FORWARD & BACKWARD)
#######
sub output_multi($)
{
	my $message = shift;
	my $data    = $message->message();

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

sub gen_output_multi(;$$)
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
			ORDER BY RAND()
			LIMIT 1
		~;
		my $start = $word = db->query($query, $first, $second)->fetch;

		$phrase  = $word->{'this'};

		# Work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		my $statement = db->statement($query);

		while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__') {
			$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
		~;
		$statement = db->statement($query);

		$word = $start;
		while ($word && $word->{'next'} && $word->{'next'} ne '__END__') {
			$word = $statement->execute($word->{'this'}, $word->{'next'})->fetch;
			$phrase = "$phrase $word->{'this'}";
		}
	} elsif ($first) {
		# Find something starting with this
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		my $start = $word = db->query($query, $first)->fetch;

		$phrase  = $word->{'this'};

		# First work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND()
		~;
		my $statement = db->statement($query);

		while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__') {
			$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
		~;
		$statement = db->statement($query);

		$word = $start;
		while ($word && $word->{'next'} && $word->{'next'} ne '__END__') {
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
sub output_from_end($)
{
	my $message = shift;
	my $data    = $message->message();

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

sub gen_output_from_end(;$$)
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
			ORDER BY RAND() DESC
			LIMIT 1
		~;
		$word = db->query($query, $first, $second)->fetch;

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
			WHERE this = ? AND next = '__END__'
			ORDER BY RAND() DESC
			LIMIT 1
		~;
		$word = db->query($query, $first)->fetch;

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		## First, get count of rows
		my $query = qq~
			SELECT COUNT(*) AS count
			FROM words
			WHERE next = '__END__'
		~;
		my $count = db->statement($query)->fetch('count');

		## Now pick a random number between 0 and $count - 1
		my $row = int(rand($count));

		## Now get the $row-th row
		$query = qq~
			SELECT prev, this
			FROM words
			WHERE next = '__END__'
			LIMIT $row, 1
		~;
		$word = db->query($query)->fetch;
	}

	$phrase = "$word->{'this'} $phrase";
	if ($word->{'prev'} eq '__BEGIN__') {
		return $phrase;
	}

	$query = qq~
		SELECT prev, this
		FROM words
		WHERE this = ? AND next = ?
		ORDER BY RAND() DESC
		LIMIT 1
	~;
	my $statement = db->statement($query);

	my $count = 0;
	do {
		# Get next word
		$word = $statement->execute($word->{'prev'}, $word->{'this'})->fetch;
		unless ($word && $word->{'this'}) {
			last;
		}

		$phrase = "$word->{'this'} $phrase";

	} while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__' && $count++ <= 25);
	return $phrase;
}

#######
## LEARN
#######
sub learn($)
{
	my $message = shift;
	my $data    = $message->message();

	# Skip #mefi bots (TODO: generalize this)
	return if ($message->from() eq 'lrrr' || $message->from() eq 'douglbutt' || $message->from() eq 'shake');

	my @parts = split(/\s+/, $data);

	return if scalar(@parts) == 0;

	unshift @parts, '__BEGIN__';
	push @parts, '__END__';

	my $lookup_sql = q(
		SELECT prev, this, next
		FROM words
		WHERE prev = LEFT(?, 255) AND this = LEFT(?, 255) AND next = LEFT(?, 255)
	);
	my $lookup = db->statement($lookup_sql);

	my $insert_sql = q(
		INSERT INTO words
		(prev, this, next)
		VALUES
		(?, ?, ?)
	);
	my $insert = db->statement($insert_sql);

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
sub respond_if_addressed($)
{
	my $message = shift;
	my $data    = $message->message();

	return unless $message->is_explicit();

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
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s' and '%s'", $words[0], $words[1]);
				# Use first two words
				$msg = gen_output($words[0], $words[1]);
			} elsif ($r < .4) {
				# Pick random word and its follower
				$r = int(rand(scalar(@words) - 1));
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s' and '%s'", $words[ $r ], $words[ $r + 1 ]);
				$msg = gen_output($words[$r], $words[$r + 1]);
			} elsif ($r < .6) {
				# Pick first word
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[0]);
				$msg = gen_output($words[0]);
			} elsif ($r < .8) {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[ $r ]);
				$msg = gen_output($words[$r]);
			} else {
				# No word
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from random word");
				$msg = gen_output();
			}
		} elsif ($r < .8) { # bidirectional markov
			# Now figure out which word(s) to use
			$r = rand();
			if ($r < .25) {
				# Use first two words
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s' and '%s'", $words[0], $words[1]);
				$msg = gen_output_multi($words[0], $words[1]);
			} elsif ($r < .5) {
				# Pick random word and its follower
				$r = int(rand(scalar(@words) - 1));
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s' and '%s'", $words[ $r ], $words[ $r + 1 ]);
				$msg = gen_output_multi($words[$r], $words[$r + 1]);
			} elsif ($r < .75) {
				# Use first word
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[0]);
				$msg = gen_output_multi($words[0]);
			} else {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[ $r ]);
				$msg = gen_output_multi($words[$r]);
			}
		} else { # reverse markov
			# Now figure out which word(s) to use
			my $r = rand();
			if ($r < .3333) {
				# Use last two words
				my $n = scalar(@words) - 1;
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s' and '%s'", $words[ $n - 1 ], $words[ $n ]);
				$msg = gen_output_from_end($words[$n - 1], $words[$n]);
			} elsif ($r < .66666) {
				# Use last word
				my $n = scalar(@words) - 1;
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s'", $words[ $n ]);
				$msg = gen_output_from_end($words[$n]);
			} else {
				# Pick random word
				$r = int(rand(scalar(@words)));
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating vokram response from '%s'", $words[ $r ]);
				$msg = gen_output_from_end($words[$r]);
			}
		}
	} else {
		if (rand() < .5) {
			if (rand() < .5) {
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from '%s'", $words[0]);
				$msg = gen_output($words[0]);
			} else {
				GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov2 response from '%s'", $words[0]);
				$msg = gen_output_multi($words[0]);
			}
		} else {
			GIR::Bot::debug("Modules::Markov::respond_if_addressed: Generating markov response from random word");
			$msg = gen_output();
		}
	}
	return $msg;
}

#######
## HELP
#######
sub help($)
{
	my $message = shift;

	if ($message->message() eq 'markov') {
		return "'markov [<word> [<word>]]': create and print a Markov chain starting with the given word(s). At most two words can be used to start the chain. See also 'markov2' and 'vokram'";
	} elsif ($message->message() eq 'markov2') {
		return "'markov2 <word> [<word>]': create and print a Markov chain containing the given word(s). This can appear anywhere in the chain, not just at the beginning. See also 'markov' and 'vokram'";
	} elsif ($message->message() eq 'vokram') {
		return "'vokram <word> [<word>]': create and print a Markov chain that ends with the given word(s). At most two words can be used as the basis for the chain. See also 'markov' and 'markov2'";
	}
}

1;
