package Modules::Translate;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use Encode;
use HTTP::Request;
use LWP::UserAgent;
use URI::Escape qw/ uri_escape /;
use XML::Simple;

##############
sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	# Check for necessary configuration parameters
	my $moduleConfig = $Bot::config->{'modules'}->{'Translate'};
	if (not defined $moduleConfig) {
		Bot::status("Modules::Translate: no configuration information present, skipping initialization");
		return -1;
	}

	unless ($moduleConfig->{'app_id'}) {
		Bot::status("Modules::Translate: no 'app_id' configuration value provided, skipping initialization");
		return -1;
	}

	&Modules::register_action('translate', \&Modules::Translate::translate);

	&Modules::register_help('translate', \&Modules::Translate::help);
}

sub translate($)
{
	my $message = shift;

	# Check for valid format (two-character language code plus some text)
	my $data = $message->message();
	unless ($data =~ /^\s*\[?(\w{2})\]?\s+(.+)/) {
		return;
	}

	my ($toCode, $text) = ($1, $2);

	my $fromCode = 'en'; # default to translating from English
	if ($data =~ /\s*\[?(\w{2})\]?\s+\[(\w{2})\]\s+(.+)/) {
		$fromCode = $1;
		$toCode   = $2;
		$text     = $3;
	}

	my $translation = _getTranslation($fromCode, $toCode, $text);

	if ($translation) {
		return $translation;
	}
	return undef;
}

sub _getTranslation($$$)
{
	my ($fromLanguage, $toLanguage, $text) = @_;
	$text = uri_escape($text);

	my $appId = $Bot::config->{'modules'}->{'Translate'}->{'app_id'};

	my $url = sprintf('http://api.microsofttranslator.com/v2/Http.svc/Translate?appId=%s&from=%s&to=%s&text=%s', $appId, $fromLanguage, $toLanguage, $text);
	my $agent = new LWP::UserAgent();
	$agent->timeout(10);

	my $request = new HTTP::Request('GET', $url);
	my $response = $agent->request($request);

	if ($response->is_success()) {
		my $content = $response->content();
		my $doc = XMLin($content);
		return Encode::encode('UTF-8', $doc->{'content'});
	}
}

sub help($)
{
	my $message = shift;

	return qq('translate [ <from lang> ] <to lang> <message>': translates the message between languages.
The 'from' language defaults to English if not provided; if specifying both languages, put the 'to' language in square brackes (e.g., [it]).);
}

1;
