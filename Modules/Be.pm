package Modules::Be;

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

#	GIR::Modules::register_action('be', \&Modules::Be::output);
}

#######
## OUTPUT
#######
sub output()
{
	my $message = shift;

	return unless $message->is_addressed();

	my $query = qq~
		SELECT this, next
		FROM markov
		WHERE prev = '__BEGIN__' AND who = ?
		ORDER BY count * RAND() DESC
	~;
	my $word = db->query($query, $message->message)->fetch;

	unless ($word && $word->{'this'}) {
		return;
	}

	my $phrase = '';
	my $words  = 0;

	$query = qq~
		SELECT prev, this, next
		FROM markov
		WHERE prev = ? AND this = ? AND who = ?
		ORDER BY count * RAND() DESC
	~;
	my $statement = db->statement($query);
	while ($word && $word->{'this'} ne '__END__' && $words++ < 50) {
		$phrase = $phrase . $word->{'this'} . ' ';
		$word   = $statement->execute($word->{'this'}, $word->{'next'}, $message->message)->fetch;
	}

	chomp $phrase;

	return $phrase;
}

1;
