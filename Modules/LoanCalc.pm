package Modules::LoanCalc;

use strict;

sub new()
{
	return bless { }, shift;
}

sub register()
{
	Modules::register_action('loancalc', \&Modules::LoanCalc::calculate);
	Modules::register_help('loancalc', \&Modules::LoanCalc::help);
}

sub calculate()
{
	my $message = shift;

	my ($amount, $rate, $term) = split(/\s+/, $message->message());

	unless (defined $amount && defined $rate && defined $term) {
		if ($message->is_explicit()) {
			return "USAGE: loancalc <amount> <rate> <term>";
		}
		return undef;
	}

	if ($amount !~ /^\$?(\d+(\.\d+)?)$/) {
		return $message->is_explicit() ? "Invalid format for amount" : undef;
	}
	$amount = $1;

	if ($rate !~ /^(\d+(\.\d+)?)\%?$/) {
		return $message->is_explicit() ? "Invalid format for rate" : undef;
	}
	$rate = $1;

	if ($term !~ /^\d+$/) {
		return $message->is_explicit() ? "Invalid format for term" : undef;
	}

	my ($monthlyPayment, $interestPaid) = _calculate($amount, $rate, $term);

	return sprintf('The monthly payment on a %d-month, %.02f%% loan for $%.02f is $%.02f. Total interest paid: $%.02f', $term, $rate, $amount, $monthlyPayment, $interestPaid);
}

sub _calculate($$$)
{
	my ($amount, $rate, $term) = @_;

	$rate /= 100; # convert percentage (e.g., 8%) to underlying value (e.g., 0.08)
	my $monthlyRate = $rate / 12;

	my $monthlyPayment = $amount * ($monthlyRate + ($monthlyRate / ( ( (1 + $monthlyRate) ** $term) - 1) ) );

	my $totalPaid = $monthlyPayment * $term;
	my $interestPaid = $totalPaid - $amount;

	return ($monthlyPayment, $interestPaid);
}

sub help()
{
	return "'loancalc <amount> <rate> <term>' - calculate monthly payment and total interest for a loan of the given amount (in dollars), rate (percent), and term (months)";
}

1;
