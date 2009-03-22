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

	&Modules::register_action('quote', \&Modules::Stock::quote);
	&Modules::register_action('squote', \&Modules::Stock::short_quote);

	&Modules::register_help('quote', \&Modules::Stock::help);
	&Modules::register_help('squote', \&Modules::Stock::help);
}

sub quote()
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

sub short_quote()
{
	my ($type, $user, $symbol, $where) = @_;

	$symbol = uc($symbol);

	my $finance = new Finance::Quote;

	my %info = $finance->fetch('usa', $symbol);

	if ($info{$symbol,'last'}  eq '0.00') {
		return;
	}

	return "$symbol: $info{$symbol,'last'}, $info{$symbol,'net'} ($info{$symbol,'p_change'}%)";
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	if ($data eq 'quote') {
		return "'quote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site. See also 'squote'";
	} else {
		return "'quote <symbol>' displays current stock information for the given symbol, retrieved from the Yahoo! Finance site, in a compact format. See also 'quote'";
	}
}

1;
