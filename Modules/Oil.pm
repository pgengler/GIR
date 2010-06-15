package Modules::Oil;

use strict;

use LWP::Simple;

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

	&Modules::register_action('how much is oil', \&Modules::Oil::fetch);
}

sub fetch($)
{
	my $params = shift;

	my $url = 'http://www.howmuchisoil.com/csv.cgi';

	my $result = get($url);

	if ($result) {
		chomp $result;
		my ($price, $change, $pchange, $date, $time) = split(/,/, $result);

		return sprintf('As of %s on %s, oil was at $%.2f, %s $%.2f (%s%%)', $time, $date, $price, ($change > 0) ? 'up' : 'down', abs($change), abs($pchange));
	}
}

1;
