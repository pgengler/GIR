package Modules::QDB;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use HTML::Entities;
use LWP::UserAgent;

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

	&Modules::register_action('qdb', \&Modules::QDB::process);

	&Modules::register_help('qdb', \&Modules::QDB::help);
}

sub process($)
{
	my $message = shift;

	# Check for valid id
	my $data = '';
	if ($message->message() =~ /^\s*(\d+)\s*$/) {
		$data = $1;
	} else {
		return;
	}

	# Look for quote in DB cache
	my $db = new Database::MySQL();
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $sql = qq(
		SELECT quote
		FROM qdbquotes
		WHERE id = ?
	);
	$db->prepare($sql);
	my $sth = $db->execute($data);
	my $row = $sth->fetchrow_hashref();

	my $quote = $row ? $row->{'quote'} : undef;

	if ($quote) {
		return $quote;
	}

	# Fetch from qdb.us
	my $ua = new LWP::UserAgent;
#	if (my $proxy = Bot::getparam('httpproxy')) {
#		$ua->proxy('http', $proxy)
#	};

	$ua->timeout(10);
	my $request = new HTTP::Request('GET', "http://qdb.us/$data");
	my $response = $ua->request($request); 

	if (!$response->is_success) {
		return "Couldn't get quote. Either it doesn't exist or qdb.us is down.";
	}

	my $content = $response->content;

	if ($content =~ /\<p class=q\>\<b\>#$data\<\/b\>\<br\>(.+?)(\<br\>\<i\>Comment\:\<\/i\>(.+?))?\<\/p\>/s) {
		my $quote = _process($1);
		_saveQuote($data, $quote);
		return $quote;
	} elsif ($content =~ /\<span class=qt id=qt$data\>(.+?)\<\/span\>/s) {
		my $quote = _process($1);
		_saveQuote($data, $quote);
		return $quote;
	} else {
		return "Couldn't get quote $data. It probably doesn't exist.";
	}
}

sub help($)
{
	my $message = shift;

	return "'qdb <id>': retrieves quote <id> from qdb.us and displays it.";
}

sub _process($)
{
	my ($quote) = @_;

	$quote = HTML::Entities::decode_entities($quote);
	$quote =~ s/\<br \/\>/\n/g;

	return $quote;
}

sub _saveQuote($$)
{
	my ($id, $quote) = @_;

	my $db = new Database::MySQL();
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $sql = q(
		INSERT INTO qdbquotes
		(id, quote)
		VALUES
		(?, ?)
	);
	$db->prepare($sql);
	$db->execute($id, $quote);
}

1;
