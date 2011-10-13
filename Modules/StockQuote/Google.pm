package StockQuote::Google;

use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use HTTP::Request;
use LWP::UserAgent;

use constant {
	URL_FORMAT => 'http://www.google.com/finance?q=%s',
};

sub new()
{
	my $class = shift;
	my ($symbol) = @_;

	my $self = {
		'symbol' => $symbol,
	};

	return bless $self, $class;
}

sub fetch()
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

	my $userAgent = new LWP::UserAgent();
	$userAgent->timeout(10);

	my $request = new HTTP::Request('GET', $url);

	my $response = $userAgent->request($request);

	if (!$response->is_success()) {
		return undef;
	}

	my $tree = new HTML::TreeBuilder::XPath();
	$tree->parse_content($response->content());

	my $title = $tree->findvalue('/html/head/title');
	return undef unless $title =~ /quotes & news/;

	my ($name, $extra)      = split(/: /, $title);
	my ($fullSymbol, $xtra) = split(/\s/, $extra);

	my $info = {
		'symbol'    => $fullSymbol,
		'name'      => $name,
		'price'     => $tree->findvalue('/html/body//span[@class="pr"]/span'),
		'change'    => $tree->findvalue('/html/body//span[@class="chg"][1]') || $tree->findvalue('/html/body//span[@class="chr"][1]'),
		'pctChange' => $tree->findvalue('/html/body//span[@class="chg"][2]') || $tree->findvalue('/html/body//span[@class="chr"][2]'),
		'open'      => $tree->findvalue('/html/body//span[@data-snapfield="open"]/following-sibling::span'),
		'dayRange'  => $tree->findvalue('/html/body//span[@data-snapfield="range"]/following-sibling::span'),
		'yearRange' => $tree->findvalue('/html/body//span[@data-snapfield="range_52week"]/following-sibling::span'),
	};

	return $info;
}

sub AUTOLOAD()
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