package Modules::Bash;

use strict;

use Util;

use HTML::Entities;

##############
sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

my $bash_url_expr = qr[http://bash.org/\?(\d+)$];

sub register()
{
	my $this = shift;

	Modules::register_action('bash', \&Modules::Bash::process_from_text);
	Modules::register_action($bash_url_expr, \&Modules::Bash::process_from_url);

	Modules::register_help('bash', \&Modules::Bash::help);
}

sub process_from_url($)
{
	my ($message) = @_;

	if ($message->message() =~ $bash_url_expr) {
		return _get_quote($1);
	}

	return undef;
}

sub process_from_text($)
{
	my ($message) = @_;

	if ($message->message() =~ /(\d+)/) {
		return _get_quote($1);
	}

	return undef;
}

sub _get_quote($)
{
	my ($id) = @_;

	my $sql = qq(
		SELECT quote
		FROM bashquotes
		WHERE id = ?
	);
	my $row = db->query($sql, $id)->fetch;

	my $quote = $row ? $row->{'quote'} : undef;

	if ($quote) {
		return $quote;
	}

	# Fetch from bash.org
	my $url = "http://bash.org/?${id}";
	my $content = eval { get_url($url) };

	if ($@) {
		return "Something failed in connecting to bash.org. Try again later.";
	}

	if ($content =~ /Quote #${id} was rejected/ || $content =~ /Quote #${id} does not exist/ || $content =~ /Quote #${id} is pending moderation/) {
		return "Couldn't get quote ${id}. It probably doesn't exist";
	}

	if ($content =~ /\<p class=\"qt\"\>(.+?)\<\/p\>/s) {
		my $quote = HTML::Entities::decode_entities($1);
		$quote =~ s/\<br \/\>/\n/g;

		$sql = qq(
			INSERT INTO bashquotes
			(id, quote)
			VALUES
			(?, ?)
		);
		db->query($sql, $id, $quote);

		return $quote;
	} else {
		return "Couldn't get quote ${id}. It probably doesn't exist.";
	}
}

sub help($)
{
	my $message = shift;

	return "'bash <id>': retrieves quote <id> from bash.org and displays it.";
}

1;
