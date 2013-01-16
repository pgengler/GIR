package Modules::QDB;

use strict;

use GIR::Util;

use HTML::Entities;

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

	GIR::Modules::register_action('qdb', \&Modules::QDB::process_from_text);
	GIR::Modules::register_action($qdb_expr, \&Modules::QDB::process_from_url);

	GIR::Modules::register_help('qdb', \&Modules::QDB::help);
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
	my $sql = qq(
		SELECT quote
		FROM qdbquotes
		WHERE id = ?
	);
	my $quote = db->query($sql, $id)->fetch('quote');

	if ($quote) {
		return $quote;
	}

	# Fetch from qdb.us
	my $url = "https://qdb.us/${id}";
	my $content = eval { get_url($url) };

	if ($@) {
		return "Couldn't get quote. Either it doesn't exist or qdb.us is down.";
	}

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

	my $sql = q(
		INSERT INTO qdbquotes
		(id, quote)
		VALUES
		(?, ?)
	);
	db->query($sql, $id, $quote);
}

1;
