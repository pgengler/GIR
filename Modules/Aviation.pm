package Modules::Aviation;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
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

	&Modules::register_action('metar', \&Modules::Aviation::metar);
	&Modules::register_action('taf', \&Modules::Aviation::taf);

	&Modules::register_help('metar', \&Modules::Aviation::help);
	&Modules::register_help('taf', \&Modules::Aviation::help);
}

sub metar($)
{
	my $params = shift;

	my $data = $params->{'message'};
	unless ($data =~ /^\s*[\w\d]{3,4}\s*$/) {
		return "$data doesn't seem to be a valid airport identifier";
	}

	$data = uc($data);

	if (length($data) == 3 && $data =~ /^Y/) {
		$data = "C$data";
	} elsif (length($data) == 3) {
		$data = "K$data";
	}

	my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=$data";
	
	# Grab METAR report from Web.
	my $agent   = new LWP::UserAgent;
	my $request = new HTTP::Request(GET => $metar_url);
	my $reply   = $agent->request($request);
	
	unless ($reply->is_success) {
		return "Either $data doesn't exist (try a 4-letter station code like KAGC), or the site NOAA site is unavailable right now.";
	}
	
	# extract METAR from incredibly and painfully verbose webpage
	my $webdata = $reply->as_string;
	$webdata =~ m/($data\s\d+Z.*?)</s;    
	my $metar = $1;
	$metar =~ s/\n//gm;
	$metar =~ s/\s+/ /g;
	
	# Sane?
	return "I can't find any observations for $data." if length($metar) < 10;

	return $metar;
}

sub taf($)
{
	my $params = shift;

	my $data = $params->{'message'};
	unless ($data =~ /^\s*[\w\d]{3,4}\s*$/) {
		return "$data doesn't seem to be a valid airport identifier";
	}

	$data = uc($data);

	if (length($data) == 3 && $data =~ /^Y/) {
		$data = "C$data";
	} elsif (length($data) == 3) {
		$data = "K$data";
	}
	
	my $taf_url = "http://weather.noaa.gov/cgi-bin/mgettaf.pl?cccc=$data";
	
	# Grab METAR report from Web.   
	my $agent   = new LWP::UserAgent;
	my $request = new HTTP::Request(GET => $taf_url);
	my $reply = $agent->request($request);
	
	unless ($reply->is_success) {
		return "Either $data doesn't exist (try a 4-letter station code like KAGC), or the site NOAA site is unavailable right now.";
	}
	
	# extract TAF from equally verbose webpage
	my $webdata = $reply->as_string;
	$webdata =~ m/($data( AMD)* \d+Z .*?)</s; 
	my $taf = $1;                       
	$taf =~ s/\n//gm;
	$taf =~ s/\s+/ /g;
	
	# Highlight FM, TEMP, BECMG, PROB
	$taf =~ s/(FM\d+Z?|TEMPO \d+|BECMG \d+|PROB\d+)/\cB$1\cB/g;
	
	# Sane?
	return "I can't find any forecast for $data." if length($taf) < 10;
	
	return $taf;
}

sub help($)
{
	my $params = shift;

	if ($params->{'message'} eq 'metar') {
		return "'metar <airport>': Fetches and displays the last available METAR for the given airport.";
	} elsif ($params->{'message'} eq 'taf') {
		return "'taf <airport>': Fetches and displays the last available TAF for the given airport.";
	}
}

1;
