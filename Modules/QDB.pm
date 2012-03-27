package Modules::QDB;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Database::MySQL;
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

my $qdb_expr = qr[^http://qdb.us/(\d+)$];

sub register()
{
	my $this = shift;

	Modules::register_action('qdb', \&Modules::QDB::process_from_text);
	Modules::register_action($qdb_expr, \&Modules::QDB::process_from_url);

	Modules::register_help('qdb', \&Modules::QDB::help);
}

sub process_from_url($)
{
	my ($message) = @_;

	# Extract ID
	if ($message->message() =~ $qdb_expr) {
		return _get_quote($1);
	}
	return undef;
}

sub process_from_text($)
{
	my ($message) = @_;

	# Check for valid id
	if ($message->message() =~ /^\s*(\d+)\s*$/) {
		return _get_quote($1);
	}
	return undef;
}

sub _get_quote($)
{
	my ($id) = @_;

	# Look for quote in DB cache
	my $db = new Database::MySQL();
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $sql = qq(
		SELECT quote
		FROM qdbquotes
		WHERE id = ?
	);
	$db->prepare($sql);
	my $sth = $db->execute($id);
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
	my $request = new HTTP::Request('GET', "http://qdb.us/${id}");
	my $response = $ua->request($request); 

	if (!$response->is_success) {
		return "Couldn't get quote. Either it doesn't exist or qdb.us is down.";
	}

	my $content = $response->content;

	if ($content =~ /\<p class=q\>\<b\>#$id\<\/b\>\<br\>(.+?)(\<br\>\<i\>Comment\:\<\/i\>(.+?))?\<\/p\>/s) {
		my $quote = _process($1);
		_save_quote($id, $quote);
		return $quote;
	} elsif ($content =~ /\<span class=qt id=qt$id\>(.+?)\<\/span\>/s) {
		my $quote = _process($1);
		_save_quote($id, $quote);
		return $quote;
	} else {
		return "Couldn't get quote ${id}. It probably doesn't exist.";
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
	$quote =~ s/\t/ /g;

	return $quote;
}

sub _save_quote($$)
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
