package Modules::Blurber;

use strict;

use GIR::Util;

use constant GET_BLURB_FORMAT => 'http://www.blurber.io/api/%s/0/?descr_length=30';
use constant GET_CATEGORIES_URL => 'http://www.blurber.io/api/genres/';
use JSON;

my @cats;

sub register
{
	# get the list of categories, and thereby also make sure we have a valid api connection
	my $catlist = eval { get_url(GET_CATEGORIES_URL) };

	GIR::Modules::register_action('blurber', \&Modules::Blurber::blurber);
	GIR::Bot::debug("Modules::Blurber: got category list");

	# Parse response
	my $catdata;
	eval {
		$catdata = JSON::decode_json($catlist);
	};
	if (ref($catdata) ne 'HASH') {
		GIR::Bot::error("Modules::Blurber: JSON parsing failed: %s", $@);
		return -1;
	}
	@cats = keys $catdata;
}

sub blurber
{
	my $category_requested = $cats[rand @cats];
	GIR::Bot::debug("Modules::Blurber: getting a blurb for category '%s'", $category_requested);

	my $requestURL = sprintf(GET_BLURB_FORMAT, $category_requested);

	my $content = eval { get_url($requestURL) };
	GIR::Bot::debug("Modules::Blurber: got %s", $content);

	my $data;
	eval {
		$data = JSON::decode_json($content);
	};
	if (ref($data) ne 'HASH') {
		GIR::Bot::error("Modules::Blurber: JSON parsing failed");
		return _error(-1);
	}

	return sprintf("\"%s\" by %s. %s", $data->{'fields'}->{'title'}, $data->{'fields'}->{'author'}, $data->{'fields'}->{'descr'});
}

sub _error
{
	my ($message) = @_;

	if ($message->is_explicit) {
		return "Error connecting to blurber API";
	} else {
		return 'NOREPLY';
	}
}

1;
