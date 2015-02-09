package Modules::Aviation;

use strict;

sub register
{
	GIR::Modules->register_action('metar', \&Modules::Aviation::metar);
	GIR::Modules->register_action('taf', \&Modules::Aviation::taf);

	GIR::Modules->register_help('metar', \&Modules::Aviation::help);
	GIR::Modules->register_help('taf', \&Modules::Aviation::help);
}

sub metar
{
	my $message = shift;

	my $data = $message->message;
	unless ($data =~ /^\s*[\w\d]{3,4}\s*$/) {
		return "$data doesn't seem to be a valid airport identifier";
	}

	$data = uc($data);

	if (length($data) == 3 && $data =~ /^Y/) {
		$data = "C$data";
	} elsif (length($data) == 3) {
		$data = "K$data";
	}

	my $metar_url = "http://www.aviationweather.gov/adds/metars/?chk_metars=on&station_ids=${data}";

	# Grab METAR report from Web.
	my $content = eval { get_url($metar_url) };

	if ($@) {
		return "Either $data doesn't exist (try a 4-letter station code like KMMU), or the NOAA site is unavailable right now.";
	}

	$content =~ m|<FONT FACE="Monospace,Courier">($data\s\d+Z.*?)</FONT>|s;
	my $metar = $1;
	$metar =~ s/\n//gm;
	$metar =~ s/\s+/ /g;

	# Sane?
	return "I can't find any observations for $data." if length($metar) < 10;

	return $metar;
}

sub taf
{
	my $message = shift;

	my $data = $message->message;
	unless ($data =~ /^\s*[\w\d]{3,4}\s*$/) {
		return "$data doesn't seem to be a valid airport identifier";
	}

	$data = uc($data);

	if (length($data) == 3 && $data =~ /^Y/) {
		$data = "C$data";
	} elsif (length($data) == 3) {
		$data = "K$data";
	}

	my $taf_url = "http://www.aviationweather.gov/adds/metars/?chk_tafs=on&station_ids=${data}";

	# Grab METAR report from Web.
	my $content = eval { get_url($taf_url) };

	if ($@) {
		return "Either $data doesn't exist (try a 4-letter station code like KEWR), or the NOAA site is unavailable right now.";
	}

	# extract TAF from equally verbose webpage
	unless ($content =~ m|<font face="Monospace,Courier" size="\+1">\s*($data\s*\d+Z.+?)\s*</font>|ms) {
		return "I can't find any TAF for ${data}.";
	}
	my $taf = $1;

	# Highlight FM, TEMP, BECMG, PROB
	$taf =~ s/(FM\d+Z?|TEMPO \d+|BECMG \d+|PROB\d+)/\cB$1\cB/g;

	# Sane?
	return "I can't find any forecast for $data." if length($taf) < 10;

	return $taf;
}

sub help
{
	my $message = shift;

	if ($message->message eq 'metar') {
		return "'metar <airport>': Fetches and displays the last available METAR for the given airport.";
	} elsif ($message->message eq 'taf') {
		return "'taf <airport>': Fetches and displays the last available TAF for the given airport.";
	}
}

1;
