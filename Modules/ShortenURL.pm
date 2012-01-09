package Modules::ShortenURL;

use strict;

use constant API_URL_FORMAT => 'https://api-ssl.bitly.com/v3/shorten?format=json&login=%s&apiKey=%s&longUrl=%s';

use HTTP::Request;
use JSON;
use LWP::UserAgent;
use URI::Escape;

sub new()
{
	return bless { }, shift;
}

sub register()
{
	# Check that both a login and API key are provided in the configuration
	my $moduleConfig = $Bot::config->{'modules'}->{'ShortenURL'};
	if ($moduleConfig->{'login'} && $moduleConfig->{'api_key'}) {
		&Modules::register_action('shorten', \&Modules::ShortenURL::shorten);
	} else {
		&Bot::status("Modules::ShortenURL: Missing login and/or API key in config, skipping");
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
		&Bot::status(sprintf("Modules::ShortenURL: rejecting input '%s' because it doesn't look like a URL", $url));# if $Bot::config->{'debug'};
		return;
	}

	&Bot::status(sprintf("Modules::ShortenURL: shortening URL '%s'", $url));# if $Bot::config->{'debug'};

	# URL-encode value
	$url = URI::Escape::uri_escape($url);

	# Build request URL
	my $login  = $Bot::config->{'modules'}->{'ShortenURL'}->{'login'};
	my $apiKey = $Bot::config->{'modules'}->{'ShortenURL'}->{'api_key'};
	my $requestURL = sprintf(API_URL_FORMAT, $login, $apiKey, $url);

	my $response = _getData($requestURL);

	unless ($response) {
		return _error($message);
	}

	# Parse response
	my $data;
	eval {
		$data = JSON::decode_json($response);
	};
	if ($@ || ref($data) ne 'HASH') {
		&Bot::status("Modules::ShortenURL: JSON parsing failed");
		return _error($message);
	}

	return $data->{'data'}->{'url'};
}

sub _getData($)
{
	my ($url) = @_;

	my $ua = new LWP::UserAgent;
	$ua->timeout(10);

	my $request  = new HTTP::Request('GET', $url);
	my $response = $ua->request($request);
	unless ($response->is_success()) {
		&Bot::status(sprintf("Modules::ShortenURL: Error getting URL '%s': %s", $url, $response->status_line()));
		return undef;
	}

	return $response->content();
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
