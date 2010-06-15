package Modules::Be;

#######
## PERL SETUP
#######
use strict;
use lib ('./', '../Main');

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
	my $params = shift;

	return unless $params->{'addressed'};

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	my $query = qq~
		SELECT this, next
		FROM markov
		WHERE prev = '__BEGIN__' AND who = ?
		ORDER BY count * RAND() DESC
	~;
	$db->prepare($query);
	my $sth  = $db->execute($params->{'message'});
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
		$sth    = $db->execute($word->{'this'}, $word->{'next'}, $params->{'message'});
		$word   = $sth->fetchrow_hashref();
	}

	chomp $phrase;

	return $phrase;
}

1;
