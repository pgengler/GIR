package Modules::BeerAdvocate;

use strict;

use constant BA_URL => qr[(https://www.beeradvocate.com/beer/profile/(\d+)/(\d+?))/];

sub register
{
	GIR::Modules->register_action(BA_URL, \&show_beer_title);
}

sub show_beer_title
{
	my $message = shift;

	if ($message->message !~ BA_URL) {
		return;
	}
	my $url = $1;

	my $content = eval { get_url($url) };
	return if $@;

	if ($content =~ qr[<title>(.+?)</title>]) {
		my $title = $1;
		$title =~ s/ \| BeerAdvocate//;
		return $title;
	}
}

1;
