package StockQuote::Yahoo;

use strict;
use warnings;

use HTTP::Request;
use JSON qw/ decode_json /;
use LWP::UserAgent;
use Web::Query;

use constant URL_FORMAT => 'https://finance.yahoo.com/quote/%s';

sub new
{
	my $class = shift;
	my ($symbol) = @_;

	my $self = {
		'symbol' => $symbol,
	};

	return bless $self, $class;
}

sub fetch
{
	my $self = shift;
	my ($symbol) = @_;

	if ($symbol) {
		$self->{'symbol'} = $symbol;
	} else {
		$symbol = $self->{'symbol'};
	}

	# Get Google Finance page
	my $url = sprintf(URL_FORMAT, $symbol);

	my $userAgent = LWP::UserAgent->new;
	$userAgent->agent(qq[Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36]);
	$userAgent->timeout(10);

	my $request = HTTP::Request->new('GET', $url);

	my $response = $userAgent->request($request);

	if (!$response->is_success) {
		return undef;
	}

	if ($response->content !~ /^root.App.main = (.+?);$/m) {
		return undef;
	}
	my $line = $1;

	my $doc = decode_json($line);
	my $symbolData = $doc->{'context'}->{'dispatcher'}->{'stores'}->{'RecommendationStore'}->{'recommendedSymbols'};
	my ($canonicalSymbol) = keys %$symbolData;
	if (!$canonicalSymbol) {
		$canonicalSymbol = uc($symbol);
	}

	my $allData = $doc->{'context'}->{'dispatcher'}->{'stores'}->{'StreamDataStore'}->{'quoteData'};
	my $data = $allData->{ $canonicalSymbol };

	my $info = {
		'symbol'    => $canonicalSymbol,
		'name'      => $data->{'longName'},
		'price'     => $data->{'regularMarketPrice'}->{'fmt'},
		'change'    => $data->{'regularMarketChange'}->{'fmt'},
		'pctChange' => $data->{'regularMarketChangePercent'}->{'fmt'},
		'open'      => $data->{'regularMarketOpen'}->{'fmt'},
		'dayRange'  => $data->{'regularMarketDayRange'}->{'fmt'},
		'yearRange' => $data->{'fiftyTwoWeekRange'}->{'fmt'},
	};

	if (!$info->{'price'}) {
		return undef;
	}

	foreach my $key (keys %$info) {
		# Trim leading/trailing whitespace characters
		$info->{ $key } =~ s/^\s*//;
		$info->{ $key } =~ s/\s*$//;
		# Convert any remaining whitespace into single space characters
		$info->{ $key } =~ s/\s+/ /g;

		# Replace Unicode minus sign with ASCII hyphen
		$info->{ $key } =~ s/−/-/g;
	}

	return $info;
}

sub AUTOLOAD
{
	my $self = shift;

	my $name = our $AUTOLOAD;
	$name =~ s/.*:://;

	return if ($name =~ /^(DESTROY)$/);

	if ($name =~ /^_/ || !exists $self->{ $name }) {
		die "Invalid method '$name'";
	}

	return $self->{ $name };
}

1;
