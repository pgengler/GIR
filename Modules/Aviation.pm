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

	my $metar_url = "https://aviationweather.gov/cgi-bin/data/metar.php?ids=${data}&hours=0&order=id%2C-obs&sep=true";

	# Grab METAR report from Web.
	my $content = eval { get_url($metar_url) };

	if ($@) {
		return "Either $data doesn't exist (try a 4-letter station code like KMMU), or the NOAA site is unavailable right now.";
	}

	my $metar = $content;
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

	my $taf_url = "https://aviationweather.gov/cgi-bin/data/taf.php?ids=${data}&sep=true";

	# Grab METAR report from Web.
	my $content = eval { get_url($taf_url) };

	if ($@) {
		return "Either $data doesn't exist (try a 4-letter station code like KEWR), or the NOAA site is unavailable right now.";
	}

	my $taf = $content;

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
