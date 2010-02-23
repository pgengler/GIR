package Modules::Bash;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File NDBM_File) }
use AnyDBM_File;
use Fcntl;
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

sub process()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Check for valid id
	unless ($data =~ /^\d+$/) {
		return;
	}

	my $result;

	my %quotes;
	tie(%quotes, 'AnyDBM_File', $Bot::config->{'data_dir'} . '/bashquotes', O_RDWR|O_CREAT);

	# Check if we have this one cached
	if ($quotes{ $data }) {
		my $result = $quotes{ $data };
		untie %quotes;
		return $result;
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
		untie %quotes;
		return "Something failed in connecting to bash.org. Try again later.";
	}

	my $content = $response->content;

	if ($content =~ /Quote #$data was rejected/ || $content =~ /Quote #$data does not exist/ || $content =~ /Quote #$data is pending moderation/) {
		untie %quotes;
		return "Couldn't get quote $data. It probably doesn't exist";
	}

	if ($content =~ /\<p class=\"qt\"\>(.+?)\<\/p\>/s) {
		$result = &HTML::Entities::decode_entities($1);
		$result =~ s/\<br \/\>/\n/g;
		$quotes{ $data } = $result;
	} else {
		$result = "Couldn't get quote $data. It probably doesn't exist.";
	}
	untie %quotes;
	return $result;
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'bash <id>': retrieves quote <id> from bash.org and displays it.";
}


1;
