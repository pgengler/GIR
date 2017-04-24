package Modules::Translate;

use strict;

use HTTP::Headers;
use List::MoreUtils qw/ zip /;
use LWP::UserAgent;
use URI::Escape qw/ uri_escape /;
use XML::Simple qw/ xml_in /;

my $TRANSLATE_REGEX = qr/^translate\s+(.+?)\s+(from\s+(.+?))?\s*(\s*(in)?to\s+(.+?))?$/;

my $languageToCodeMap = { };

sub register
{
	# Check for necessary configuration parameters
	unless (config('subscription_key')) {
		GIR::Bot->status("Modules::Translate: no 'subscription_key' configuration value provided, skipping initialization");
		return -1;
	}

	unless (_loadLanguagesAndCodes()) {
		GIR::Bot->status('Modules::Translate: unable to load list of languages, skipping');
		return -1;
	}

	GIR::Modules->register_action($TRANSLATE_REGEX, \&translate);
	GIR::Modules->register_help('translate', \&Modules::Translate::help);
}

sub translate
{
	my $message = shift;

	my $data = $message->message;
	unless ($data =~ $TRANSLATE_REGEX) {
		return;
	}

	my ($text, $fromLanguage, $toLanguage) = ($1, $3, $6);
	$fromLanguage ||= 'english';
	$toLanguage ||= 'english';

	my $fromLanguageCode = $languageToCodeMap->{ lc($fromLanguage) };
	my $toLanguageCode = $languageToCodeMap->{ lc($toLanguage) };

	unless ($toLanguageCode) {
		GIR::Bot->status("Modules::Translate: language '${toLanguage}' not found");
		if ($message->is_explicit) {
			return "Sorry, I don't know how to translate to ${toLanguage}";
		} else {
			return 'NOREPLY';
		}
	}

	unless ($fromLanguageCode) {
		GIR::Bot->status("Modules::Translate: language '${fromLanguage}' not found");
		if ($message->is_explicit) {
			return "Sorry, I don't know how to translate from ${fromLanguage}";
		} else {
			return 'NOREPLY';
		}
	}

	if ($fromLanguageCode eq $toLanguageCode) {
		return 'NOREPLY';
	}

	return _performTranslation($text, $toLanguageCode, $fromLanguageCode);
}

sub help
{
	my $message = shift;

	return qq('translate <message> from <language> into <language>': translates the message between languages
When translating to or from English you can omit that part.);
}

sub _accessToken
{
	my $url = 'https://api.cognitive.microsoft.com/sts/v1.0/issueToken';

	my $headers = new HTTP::Headers(
		'Accept'       => 'application/jwt',
		'Content-Type' => 'application/json',
		'Ocp-Apim-Subscription-Key' => config('subscription_key')
	);

	my $agent = _userAgent($headers);
	my $response = $agent->post($url);

	unless ($response->is_success) {
		die $response->status_line;
	}

	return $response->content;
}

sub _loadLanguagesAndCodes
{
	my $accessToken = _accessToken();
	my $headers = new HTTP::Headers(
		'Authorization' => "Bearer ${accessToken}",
		'Content-Type' => 'application/xml',
	);

	my $agent = _userAgent($headers);

	my $response = $agent->get('https://api.microsofttranslator.com/V2/Http.svc/GetLanguagesForTranslate');
	unless ($response->is_success) {
		die $response->status_line;
	}
	my $codeXML = $response->content;
	my $doc = xml_in($codeXML);
	my $codes = $doc->{'string'};

	$response = $agent->post('https://api.microsofttranslator.com/V2/Http.svc/GetLanguageNames?locale=en',
		'Content' => $codeXML,
		'Content-Type' => 'application/xml'
	);
	unless ($response->is_success) {
		die $response->content;
	}
	$doc = xml_in($response->content);
	my @names = map { lc } @{ $doc->{'string'} };
	my %nameToCodeMap = zip(@names, @$codes);
	$languageToCodeMap = \%nameToCodeMap;
}

sub _performTranslation
{
	my ($text, $toLanguageCode, $fromLanguageCode) = @_;
	$text = uri_escape($text);
	$fromLanguageCode ||= 'en';
	$fromLanguageCode = uri_escape($fromLanguageCode);
	$toLanguageCode = uri_escape($toLanguageCode);

	my $accessToken = _accessToken();
	my $headers = new HTTP::Headers(
		'Authorization' => "Bearer ${accessToken}",
		'Content-Type' => 'text/plain',
	);
	my $agent = _userAgent($headers);
	my $url = sprintf('https://api.microsofttranslator.com/V2/Http.svc/Translate?from=%s&to=%s&text=%s', $fromLanguageCode, $toLanguageCode, $text);

	my $response = $agent->get($url);
	unless ($response->is_success) {
		die $response->content;
	}
	my $doc = xml_in($response->content);
	return $doc->{'content'};
}

sub _userAgent
{
	my ($headers) = @_;

	return new LWP::UserAgent(
		'agent' => 'Mozilla/5.0',
		'default_headers' => $headers,
		'timeout' => 3,
	);
}

1;
