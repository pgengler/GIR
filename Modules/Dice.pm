package Modules::Dice;

use strict;
use warnings;

my $DICE_REGEXP = qr/^(roll\s+)?(\d?)d(\d+)$/;

sub new
{
	bless { }, shift;
}

sub register
{
	GIR::Modules::register_action($DICE_REGEXP, \&roll);
}

sub roll
{
	my ($message) = @_;

	$message =~ $DICE_REGEXP;

	my ($dice, $sides) = ($2, $3);
	$dice = 1 unless $dice;

	return unless ($sides >= 4 && $sides <= 100);

	my @rolls;
	my $total = 0;
	for (1..$dice) {
		my $roll = int(rand($sides) + 1);
		push @rolls, $roll;
		$total += $roll;
	}

	my $roll_str = join(' + ', @rolls);
	my $response = sprintf('%s = %d', $roll_str, $total);
	return $response;
}

1;
