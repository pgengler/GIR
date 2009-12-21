package Modules::QDB;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use AnyDBM_File;
use Fcntl;
use LWP::UserAgent;

#######
## GLOBALS
#######
my $no_agent = 0;

BEGIN {
	eval "use LWP::UserAgent";
	$no_agent++ if ($@);
}

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

	&Modules::register_action('qdb', \&Modules::QDB::process);

	&Modules::register_help('qdb', \&Modules::QDB::help);
}

sub process()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Check for valid id
	if ($data =~ /^\s*(\d+)\s*$/) {
		$data = $1;
	} else {
		return;
	}

	my $result;

	if ($no_agent) {
		return 0;
	} else {
		my %quotes;
		tie(%quotes, 'AnyDBM_File', $Bot::config->{'data_dir'} . '/qdbquotes', O_RDWR|O_CREAT);

		# Check if we have this one cached
		if ($quotes{ $data }) {
			my $result = $quotes{ $data };
			untie %quotes;
			return $result;
		}

		# Fetch from qdb.us
		my $ua = new LWP::UserAgent;
#		if (my $proxy = Bot::getparam('httpproxy')) {
#			$ua->proxy('http', $proxy)
#		};

		$ua->timeout(10);
		my $request = new HTTP::Request('GET', "http://qdb.us/$data");
		my $response = $ua->request($request); 

		if (!$response->is_success) {
			untie %quotes;
			return "Couldn't get quote. Either it doesn't exist or qdb.us is down.";
		}

		my $content = $response->content;


		if ($content =~ /\<p class=q\>\<b\>#$data\<\/b\>\<br\>(.+?)\<\/p\>/s) {
			$result = &uncode($1);
			$quotes{ $data } = $result;
		} elsif ($content =~ /\<span class=qt id=qt$data\>(.+?)\<\/span\>/s) {
			$result = &uncode($1);
			$quotes{ $data } = $result;
		} else {
			$result = "Couldn't get quote $data. It probably doesn't exist.";
		}
		untie %quotes;
		return $result;
	}
}

##
## Unescape some HTML entities
##
sub uncode()
{
	my $str = shift;

	$str =~ s/\<br \/\>/\n/g;
	$str =~ s/&lt;/</g;
	$str =~ s/&gt;/>/g;
	$str =~ s/&apos;/'/g;
	$str =~ s/&quot;/"/g;
	$str =~ s/&nbsp;/ /g;

	return $str;
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	return "'qdb <id>': retrieves quote <id> from qdb.us and displays it.";
}

1;
