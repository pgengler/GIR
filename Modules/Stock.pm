package Modules::Stock;

use strict;

use Finance::Quote;

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

	&Modules::register_action('quote', \&Modules::Stock::process);
}

sub process()
{
	my ($type, $user, $symbol, $where) = @_;

	$symbol = uc($symbol);

	my $finance = new Finance::Quote;

	my %info = $finance->fetch('usa', $symbol);

	if ($info{$symbol,'last'}  eq '0.00') {
		return;
	}

	return $info{$symbol,'name'} . ': Last: ' . $info{$symbol,'last'} . ' Change: ' . $info{$symbol,'net'} . '(' . $info{$symbol,'p_change'} . '%) Open: ' . $info{$symbol,'open'} . ' Close: ' . $info{$symbol,'close'} . ' Day Range: ' . $info{$symbol,'day_range'} . ' Year Range: ' . $info{$symbol,'year_range'} . ' Volume: ' . $info{$symbol,'volume'};

}

1;
