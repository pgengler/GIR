package Modules::Oil;

use strict;

use GIR::Util;

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

	GIR::Modules::register_action('how much is oil', \&Modules::Oil::fetch);
}

sub fetch($)
{
	my $message = shift;

	my $url = 'http://www.howmuchisoil.com/price.cgi?format=csv';
	my $content = eval { get_url($url) };

	if ($@) {
		return "Unable to fetch current oil prices; please try again later";
	}

	chomp $content;
	my ($price, $change, $pchange, $date, $time) = split(/,/, $content);

	return sprintf('As of %s on %s, oil was at $%.2f, %s $%.2f (%s%%)', $time, $date, $price, ($change > 0) ? 'up' : 'down', abs($change), abs($pchange));
}

1;
