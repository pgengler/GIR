package Modules::Stock;

use strict;

use Modules::StockQuote::Google;

sub register
{
	GIR::Modules->register_action('quote', \&Modules::Stock::quote);
	GIR::Modules->register_action('squote', \&Modules::Stock::short_quote);

	GIR::Modules->register_help('quote', \&Modules::Stock::help);
	GIR::Modules->register_help('squote', \&Modules::Stock::help);
}

sub quote
{
	my $message = shift;

	my $symbol = $message->message;

	return unless $symbol;

	# Remove leading and trailing whitespace
	$symbol =~ s/^\s*(.+)\s*$/$1/;

	# If there's any internal whitespace, don't process
	if ($symbol =~ /\s/) {
		return;
	}

	return unless $symbol;

	if (!$message->is_explicit && ignored($symbol)) {
		GIR::Bot->debug("Modules::Stock::quote: symbol '%s' is on ignore list", $symbol);
		return 'NOREPLY';
	}

	GIR::Bot->status("Looking up stock quote for '%s'", $symbol);

	$symbol = uc($symbol);

	my $finance = StockQuote::Google->new($symbol);

	my $info = $finance->fetch;

	unless ($info) {
		GIR::Bot->status("Quote lookup failed for '%s'", $symbol);
		if ($message->is_addressed) {
			return "Unable to get quote for '$symbol'";
		}
		return undef;
	}

	return sprintf('%s: Last: %s Change: %s %s Open: %s Day Range: %s Year Range: %s', $info->{'name'}, $info->{'price'}, $info->{'change'}, $info->{'pctChange'}, $info->{'open'}, $info->{'dayRange'}, $info->{'yearRange'});
}

sub short_quote
{
	my $message = shift;

	my $symbol = $message->message;

	GIR::Bot->status("Looking up stock quote for '%s'", $symbol);

	# Remove leading and trailing whitespace
	$symbol =~ s/^\s*(.+)\s*$/$1/;

	# If there's any internal whitespace, don't process
	if ($symbol =~ /\s/) {
		return;
	}

	$symbol = uc($symbol);

	my $quote = StockQuote::Google->new($symbol);

	my $info = $quote->fetch;

	unless ($info) {
		GIR::Bot->status("Quote lookup failed for '%s'", $symbol);
		if ($message->is_addressed) {
			return "Unable to get quote for '$symbol'";
		}
		return undef;
	}

	return sprintf('%s: %s, %s %s', $info->{'name'}, $info->{'price'}, $info->{'change'}, $info->{'pctChange'});
}

sub ignored
{
	my ($symbol) = @_;

	return 0 unless $GIR::Bot::config->{'modules'}->{'Stock'}->{'ignored_symbols'};
	my $ignored_symbols = [ map { lc($_) } @{ $GIR::Bot::config->{'modules'}->{'Stock'}->{'ignored_symbols'} } ];

	return (lc($symbol) ~~ $ignored_symbols);
}

sub help
{
	my $message = shift;

	if ($message->message eq 'quote') {
		return "'quote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site. See also 'squote'.";
	} else {
		return "'squote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site, in a compact format. See also 'quote'.";
	}
}

1;
