package Modules::Be;

#######
## PERL SETUP
#######
use strict;
use lib ('./', '../lib');

#######
## INCLUDES
#######
use Database::MySQL;

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

#	&Modules::register_action('be', \&Modules::Be::output);
}

#######
## OUTPUT
#######
sub output()
{
	my $message = shift;

	return unless $message->is_addressed();

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $query = qq~
		SELECT this, next
		FROM markov
		WHERE prev = '__BEGIN__' AND who = ?
		ORDER BY count * RAND() DESC
	~;
	$db->prepare($query);
	my $sth  = $db->execute($message->message());
	my $word = $sth->fetchrow_hashref();

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
	$db->prepare($query);
	while ($word && $word->{'this'} ne '__END__' && $words++ < 50) {
		$phrase = $phrase . $word->{'this'} . ' ';
		$sth    = $db->execute($word->{'this'}, $word->{'next'}, $message->message());
		$word   = $sth->fetchrow_hashref();
	}

	chomp $phrase;

	return $phrase;
}

1;
