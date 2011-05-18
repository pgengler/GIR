package Modules::Bash;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use HTML::Entities;
use LWP::UserAgent;

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

	&Modules::register_action('bash', \&Modules::Bash::process);

	&Modules::register_help('bash', \&Modules::Bash::help);
}

sub process($)
{
	my $message = shift;

	# Check for valid id
	my $data = $message->message();
	unless ($data =~ /^\d+$/) {
		return;
	}

	# Look for quote in DB cache
	my $db = new Database::MySQL();
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $sql = qq(
		SELECT quote
		FROM bashquotes
		WHERE id = ?
	);
	$db->prepare($sql);
	my $sth = $db->execute($data);
	my $row = $sth->fetchrow_hashref();

	my $quote = $row ? $row->{'quote'} : undef;

	if ($quote) {
		return $quote;
	}

	# Fetch from bash.org
	my $ua = new LWP::UserAgent;
#	if (my $proxy = Bot::getparam('httpproxy')) {
#		$ua->proxy('http', $proxy)
#	};

	$ua->timeout(10);
	my $request = new HTTP::Request('GET', "http://bash.org/?$data");
	my $response = $ua->request($request); 

	if (!$response->is_success) {
		return "Something failed in connecting to bash.org. Try again later.";
	}

	my $content = $response->content();

	if ($content =~ /Quote #$data was rejected/ || $content =~ /Quote #$data does not exist/ || $content =~ /Quote #$data is pending moderation/) {
		return "Couldn't get quote $data. It probably doesn't exist";
	}

	if ($content =~ /\<p class=\"qt\"\>(.+?)\<\/p\>/s) {
		my $quote = &HTML::Entities::decode_entities($1);
		$quote =~ s/\<br \/\>/\n/g;

		$sql = qq(
			INSERT INTO bashquotes
			(id, quote)
			VALUES
			(?, ?)
		);
		$db->prepare($sql);
		$db->execute($data, $quote);

		return $quote;
	} else {
		return "Couldn't get quote $data. It probably doesn't exist.";
	}
}

sub help($)
{
	my $message = shift;

	return "'bash <id>': retrieves quote <id> from bash.org and displays it.";
}

1;
