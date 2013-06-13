package Modules::Nickometer;

use strict;

use POSIX;

sub register
{
	GIR::Modules::register_action('nickometer', \&Modules::Nickometer::process);

	GIR::Modules::register_help('nickometer', \&Modules::Nickometer::help);
}

sub process($)
{
	my $message = shift;

	my $nick = $message->message();

	if (lc($nick) eq 'me') {
		$nick = $message->from();
	}

	# Remove leading and trailing whitespace
	$nick =~ s/^\s*(.+?)\s*$/$1/;

	my $percentage = nickometer($nick);

	if ($percentage =~ /NaN/) {
		$percentage = "off the scale";
	} else {
		$percentage = $percentage . '%';
	}

	return "'$nick' is $percentage lame, " . $message->from();
}

sub nickometer($)
{
	my $nick = shift;

	my $score = 0;

	# Deal with special cases (precede with \ to prevent de-k3wlt0k)
	my %special_cost = (
		'69'                => 500,
		'dea?th'            => 500,
		'dark'              => 400,
		'n[i1]ght'          => 300,
		'n[i1]te'           => 500,
		'fuck'              => 500,
		'sh[i1]t'           => 500,
		'coo[l1]'           => 500,
		'kew[l1]'           => 500,
		'lame'              => 500,
		'dood'              => 500,
		'dude'              => 500,
		'[l1](oo?|u)[sz]er' => 500,
		'[l1]eet'           => 500,
		'e[l1]ite'          => 500,
		'[l1]ord'           => 500,
		'pron'              => 1000,
		'warez'             => 1000,
		'xx'                => 100,
		'\[rkx]0'           => 1000,
		'\0[rkx]'           => 1000
	);

	foreach my $special (keys %special_cost) {
		my $special_pattern = $special;
		my $raw = ($special_pattern =~ s/^\\//);
		unless ($raw) {
			$nick =~ tr/023457+8/ozeasttb/;
		}
		if ($nick =~ /$special_pattern/i) {
#			$this->punish($special_cost{$special}, "matched special case /$special_pattern/");
			$score += $special_cost{$special};
		}
	}

	# Allow Perl referencing
	$nick =~ s/^\\([A-Za-z])/$1/;

	# Punish consecutive non-alphas
	$nick =~ s/([^A-Za-z0-9]{2,})
		/my $consecutive = length($1);
		if ($consecutive) {
#			$this->punish(&slow_pow(10, $consecutive), "$consecutive total consecutive non-alphas");
			$score += slow_pow(10, $consecutive);
		}
		$1
	/egx;

	# Remove balanced brackets and punish for unmatched
	while ($nick =~ s/^([^()]*)   (\() (.*) (\)) ([^()]*)   $/$1$3$5/x ||
		$nick =~ s/^([^{}]*)   (\{) (.*) (\}) ([^{}]*)   $/$1$3$5/x ||
		$nick =~ s/^([^\[\]]*) (\[) (.*) (\]) ([^\[\]]*) $/$1$3$5/x) {
	}
	my $parentheses = ($nick =~ tr/(){}[]/(){}[]/);
	if ($parentheses) {
#		$this->punish(&slow_pow(10, $parentheses), "$parentheses unmatched " . ($parentheses == 1 ? 'parenthesis' : 'parentheses'));
		$score += slow_pow(10, $parentheses);
	}

	# An alpha caps is not lame in middle or at end, provided the first alpha is caps.
	my $orig_case = $nick;
	$nick =~ s/^([^A-Za-z]*[A-Z].*[a-z].*?)[_-]?([A-Z])/$1\l$2/;

	# A caps first alpha is sometimes not lame
	$nick =~ s/^([^A-Za-z]*)([A-Z])([a-z])/$1\l$2$3/;

	# Punish uppercase to lowercase shifts and vice-versa, modulo exceptions above
	my $case_shifts = case_shifts($orig_case);
	if ($case_shifts > 1 && $orig_case =~ /[A-Z]/) {
#		$this->punish(&slow_pow(9, $case_shifts), $case_shifts . ' case ' . (($case_shifts == 1) ? 'shift' : 'shifts'));
		$score += slow_pow(0, $case_shifts);
	}

	# Punish lame endings
	if ($orig_case =~ /[XY][^a-zA-Z]*$/) {
#		$this->punish(50, 'last alpha lame');
		$score += 50;
	}

	# Punish letter to numeric shifts and vice-versa
	my $number_shifts = number_shifts($nick);
	if ($number_shifts > 1) {
#		$this->punish(&slow_pow(9, $number_shifts), $number_shifts . ' letter/number ' . (($number_shifts == 1) ? 'shift' : 'shifts'));
		$score += slow_pow(9, $number_shifts);
	}

	# Punish extraneous caps
	my $caps = ($nick =~ tr/A-Z/A-Z/);
	if ($caps) {
#		$this->punish(&slow_pow(7, $caps), "$caps extraneous caps");
		$score += slow_pow(7, $caps);
	}

	# Now punish anything that's left
	my $remains = $nick;
	$remains =~ tr/a-zA-Z0-9//d;
	my $remains_length = length($remains);

	if ($remains) {
#		$this->punish(50 * $remains_length + &slow_pow(9, $remains_length), $remains_length . ' extraneous ' . (($remains_length == 1) ? 'symbol' : 'symbols'));
		$score += ((50 * $remains_length) + slow_pow(9, $remains_length));
	}

	# Use an appropriate function to map [0, +inf) to [0, 100)
	my $percentage = 100 * (1 + tanh(($score - 400) / 400)) * (1 - 1 / (1 + $score / 5)) / 2;

	my $digits = 2 * (2 - ceil(log(100 - $percentage) / log(10)));

	return sprintf("%.${digits}f", $percentage);
}

sub case_shifts($)
{
	# This is a neat trick suggested by freeside. Thanks freeside!
	my $shifts = shift;

	$shifts =~ tr/A-Za-z//cd;
	$shifts =~ tr/A-Z/U/s;
	$shifts =~ tr/a-z/l/s;

	return length($shifts) - 1;
}

sub number_shifts($)
{
	my $shifts = shift;

	$shifts =~ tr/A-Za-z0-9//cd;
	$shifts =~ tr/A-Za-z/l/s;
	$shifts =~ tr/0-9/n/s;

	return length($shifts) - 1;
}

sub slow_pow($$)
{
	my ($x, $y) = @_;

	return $x ** slow_exponent($y);
}

sub slow_exponent($)
{
	my $x = shift;

	return 1.3 * $x * (1 - atan($x / 6) * 2 / 3.14159);
}

sub round_up($)
{
	my $float = shift;

	return int($float) + ((int($float) == $float) ? 0 : 1);
}

sub help($)
{
	my $message = shift;

	return "'nickometer <nick>': calculates how lame a nickname is; the user behind the nick may be more or less lame, of course.";
}

1;
