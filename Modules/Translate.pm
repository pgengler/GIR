package Modules::Translate;

use strict;

use HTTP::Headers;
use JSON qw/ decode_json encode_json /;
use LWP::UserAgent;

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

sub _loadLanguagesAndCodes
{
	my $response = _userAgent()->get('https://api.cognitive.microsofttranslator.com/languages?api-version=3.0&scope=translation');
	unless ($response->is_success) {
		die $response->status_line;
	}
	my $data = decode_json($response->content);

	foreach my $code (keys %{ $data->{'translation'} }) {
		my $lang = $data->{'translation'}->{ $code };
		my $name = lc($lang->{'name'});
		my $nativeName = lc($lang->{'nativeName'});

		$languageToCodeMap->{ $name } = $code;
		$languageToCodeMap->{ $nativeName } = $code;
	}

	return 1;
}

sub _performTranslation
{
	my ($text, $toLanguageCode, $fromLanguageCode) = @_;
	$fromLanguageCode ||= 'en';

	my $headers = HTTP::Headers->new(
		'Ocp-Apim-Subscription-Key' => config('subscription_key'),
		'Content-Type' => 'application/json; charset=UTF-8',
	);

	my $agent = _userAgent($headers);
	my $url = sprintf('https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=%s&to=%s', $fromLanguageCode, $toLanguageCode);

	my $requestData = encode_json([
		{ 'Text' => $text }
	]);
	my $response = $agent->post($url, 'Content' => $requestData);
	unless ($response->is_success) {
		die $response->content;
	}
	my $data = decode_json($response->content);
	return $data->[0]->{'translations'}->[0]->{'text'};
}

sub _userAgent
{
	my ($headers) = @_;

	return LWP::UserAgent->new(
		'agent' => 'Mozilla/5.0',
		'default_headers' => $headers,
		'timeout' => 3,
	);
}

1;
