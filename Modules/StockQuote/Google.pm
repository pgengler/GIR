package StockQuote::Google;

use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use HTTP::Request;
use LWP::UserAgent;

use constant {
	URL_FORMAT => 'http://www.google.com/finance?q=%s',
};

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
	$userAgent->timeout(10);

	my $request = HTTP::Request->new('GET', $url);

	my $response = $userAgent->request($request);

	if (!$response->is_success) {
		return undef;
	}

	my $tree = HTML::TreeBuilder::XPath->new;
	$tree->parse_content($response->content);

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
		'open'      => $tree->findvalue('/html/body//td[@data-snapfield="open"]/following-sibling::td'),
		'dayRange'  => $tree->findvalue('/html/body//td[@data-snapfield="range"]/following-sibling::td'),
		'yearRange' => $tree->findvalue('/html/body//td[@data-snapfield="range_52week"]/following-sibling::td'),
	};

	foreach my $key (keys %$info) {
		# Trim leading/trailing whitespace characters
		$info->{ $key } =~ s/^\s*//;
		$info->{ $key } =~ s/\s*$//;
		# Convert any remaining whitespace into single space characters
		$info->{ $key } =~ s/\s+/ /g;
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
