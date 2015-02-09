package Modules::ExchangeRates;

use strict;

use XML::Simple qw/ xml_in /;

my $handleRE = qr/\s*exchange\s+(\d*(\.\d+)?)?\s*(\w{3})\s+(for|to)\s+(\w{3})\s*/;
my $urlFormat = 'http://themoneyconverter.com/rss-feed/%s/rss.xml';

sub register
{
	GIR::Modules->register_action($handleRE, \&Modules::ExchangeRates::convert);

	GIR::Modules->register_help('exchange', \&Modules::ExchangeRates::help);
}

sub convert
{
	my $message = shift;

	$message =~ /$handleRE/;
	my ($amount, $from, $to) = ($1, uc($3), uc($5));

	GIR::Bot->debug('Modules::ExchangeRates: Exchanging %s to %s', $from, $to);

	my $url = sprintf($urlFormat, $from);
	GIR::Bot->debug('Modules::ExchangeRates: Fetching URL %s', $url);
	my $content = eval { get_url($url) };

	if ($@) {
		return "Couldn't fetch conversions for '${from}'";
	}

	my $conversions = _parse($content);

	if (not exists $conversions->{ $to }) {
		return "Can't convert between '${from}' and '${to}'";
	}

	my $conversion = $conversions->{ $to };

	if ($amount) {
		$conversion =~ /= (\d+\.\d+)/;
		my $rate = $1;
		my $result = $amount * $rate;
		$conversion =~ s/^1/$amount/;
		$conversion =~ s/$rate/$result/;
	}

	return $conversion;
}

sub help
{
	my $message = shift;

	return "'exchange <from> to <to>': gets the exchange rate between the two currencies";
}

sub _parse
{
	my ($data) = @_;

	my $doc = xml_in($data, 'ForceArray' => 'item');

	my $conversions = { };

	foreach my $item (@{ $doc->{'channel'}->[0]->{'item'} }) {
		my ($to, $from) = split(/\//, $item->{'title'}->[0]);
		$conversions->{ $to } = $item->{'description'}->[0];
	}

	return $conversions;
}

1;
