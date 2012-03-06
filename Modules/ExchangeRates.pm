package Modules::ExchangeRates;

#######
## PERL SETUP
#######
use strict;

##############
sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

my $handleRE = qr/\s*exchange\s+(\d*(\.\d+)?)?\s*(\w{3})\s+(for|to)\s+(\w{3})\s*/;
my $urlFormat = 'http://themoneyconverter.com/%s/rss.xml';

sub register()
{
	my $this = shift;

	&Modules::register_action($handleRE, \&Modules::ExchangeRates::convert);

	&Modules::register_help('exchange', \&Modules::ExchangeRates::help);
}

sub convert($)
{
	my $message = shift;

	$message =~ /$handleRE/;
	my ($amount, $from, $to) = ($1, uc($3), uc($5));

	Bot::debug('Modules::ExchangeRates: Exchanging %s to %s', $from, $to);

	my $url = sprintf($urlFormat, $from);
	Bot::debug('Modules::ExchangeRates: Fetching URL %s', $url);
	my $content = _fetch($url);

	if ($content) {

		my $conversions = _parse($content);

		if (exists $conversions->{ $to }) {
			my $conversion = $conversions->{ $to };

			if ($amount) {
				$conversion =~ /= (\d+\.\d+)/;
				my $rate = $1;
				my $result = $amount * $rate;
				$conversion =~ s/^1/$amount/;
				$conversion =~ s/$rate/$result/;
			}

			return $conversion;
		} else {
			return "Can't convert between '$from' and '$to'";
		}

	} else {
		return "Couldn't fetch conversions for '$from'";
	}
}

sub help($)
{
	my $message = shift;

	return "'exchange <from> to <to>': gets the exchange rate between the two currencies";
}

sub _fetch($)
{
	my ($url) = @_;

	my $ua = new LWP::UserAgent();
	$ua->timeout(10);
	my $request = new HTTP::Request('GET', $url);
	my $response = $ua->request($request);

	return undef unless $response->is_success();

	return $response->content();
}

sub _parse($)
{
	my ($data) = @_;

	my $xml = new XML::Simple();
	my $doc = $xml->xml_in($data, 'ForceArray' => 'item');

	my $conversions = { };

	foreach my $item (@{ $doc->{'channel'}->[0]->{'item'} }) {
		my ($to, $from) = split(/\//, $item->{'title'}->[0]);
		$conversions->{ $to } = $item->{'description'}->[0];
	}

	return $conversions;
}

1;
