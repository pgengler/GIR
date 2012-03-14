package Modules::Stock;

use strict;

use Modules::StockQuote::Google;

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

	Modules::register_action('quote', \&Modules::Stock::quote);
	Modules::register_action('squote', \&Modules::Stock::short_quote);

	Modules::register_help('quote', \&Modules::Stock::help);
	Modules::register_help('squote', \&Modules::Stock::help);
}

sub quote($)
{
	my $message = shift;

	my $symbol = $message->message();

	return unless $symbol;

	# Remove leading and trailing whitespace
	$symbol =~ s/^\s*(.+)\s*$/$1/;

	# If there's any internal whitespace, don't process
	if ($symbol =~ /\s/) {
		return;
	}

	return unless $symbol;

	Bot::status("Looking up stock quote for '%s'", $symbol);

	$symbol = uc($symbol);

	my $finance = new StockQuote::Google($symbol);

	my $info = $finance->fetch();

	unless ($info) {
		Bot::status("Quote lookup failed for '%s'", $symbol);
		if ($message->addressed()) {
			return "Unable to get quote for '$symbol'";
		}
		return undef;
	}

	return sprintf('%s: Last: %s Change: %s %s Open: %s Day Range: %s Year Range: %s', $info->{'name'}, $info->{'price'}, $info->{'change'}, $info->{'pctChange'}, $info->{'open'}, $info->{'dayRange'}, $info->{'yearRange'});
}

sub short_quote($)
{
	my $message = shift;

	my $symbol = $message->message();

	Bot::status("Looking up stock quote for '%s'", $symbol);

	# Remove leading and trailing whitespace
	$symbol =~ s/^\s*(.+)\s*$/$1/;

	# If there's any internal whitespace, don't process
	if ($symbol =~ /\s/) {
		return;
	}

	$symbol = uc($symbol);

	my $quote = new StockQuote::Google($symbol);

	my $info = $quote->fetch();

	unless ($info) {
		Bot::status("Quote lookup failed for '%s'", $symbol);
		if ($message->addressed()) {
			return "Unable to get quote for '$symbol'";
		}
		return undef;
	}

	return sprintf('%s: %s, %s %s', $info->{'name'}, $info->{'price'}, $info->{'change'}, $info->{'pctChange'});
}

sub help($)
{
	my $message = shift;

	if ($message->message() eq 'quote') {
		return "'quote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site. See also 'squote'.";
	} else {
		return "'squote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site, in a compact format. See also 'quote'.";
	}
}

1;
