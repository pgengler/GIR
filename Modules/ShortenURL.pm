package Modules::ShortenURL;

use strict;

use GIR::Util;

use constant API_URL_FORMAT => 'https://api-ssl.bitly.com/v3/shorten?format=json&login=%s&apiKey=%s&longUrl=%s';

use JSON;
use URI::Escape;

sub register
{
	# Check that both a login and API key are provided in the configuration
	my $moduleConfig = $GIR::Bot::config->{'modules'}->{'ShortenURL'};
	if ($moduleConfig->{'login'} && $moduleConfig->{'api_key'}) {
		GIR::Modules::register_action('shorten', \&Modules::ShortenURL::shorten);
	} else {
		GIR::Bot::status("Modules::ShortenURL: Missing login and/or API key in config, skipping");
		return -1;
	}
}

sub shorten()
{
	my ($message) = @_;

	my $url = $message->message();

	# Remove leading and trailing whitespace
	$url =~ s/^\s*(.+?)\s*$/$1/;

	# Check for reasonably URL-like thing
	unless ($url =~ m[^(ftp|http|https)://]) {
		GIR::Bot::debug("Modules::ShortenURL: rejecting input '%s' because it doesn't look like a URL", $url);
		return;
	}

	GIR::Bot::debug("Modules::ShortenURL: shortening URL '%s'", $url);

	# URL-encode value
	$url = URI::Escape::uri_escape($url);

	# Build request URL
	my $login  = $GIR::Bot::config->{'modules'}->{'ShortenURL'}->{'login'};
	my $apiKey = $GIR::Bot::config->{'modules'}->{'ShortenURL'}->{'api_key'};
	my $requestURL = sprintf(API_URL_FORMAT, $login, $apiKey, $url);

	my $content = eval { get_url($requestURL) };

	if ($@) {
		return _error($message);
	}

	# Parse response
	my $data;
	eval {
		$data = JSON::decode_json($content);
	};
	if ($@ || ref($data) ne 'HASH') {
		GIR::Bot::error("Modules::ShortenURL: JSON parsing failed: %s", $@);
		return _error($message);
	}

	return $data->{'data'}->{'url'};
}

sub _error($)
{
	my ($message) = @_;

	if ($message->is_explicit()) {
		return "Error connecting to bit.ly API";
	} else {
		return 'NOREPLY';
	}
}

1;
