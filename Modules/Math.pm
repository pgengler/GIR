package Modules::Math;

use strict;

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

	GIR::Modules::register_listener(\&Modules::Math::process, 3);
}

sub process()
{
	my $message = shift;

	my $data = $message->message();

	if (($data !~ /^\s*$/) && ($data !~ /(\d+\.){2,}/)) {
		my $expr = $data;

		# Handle exp
		while ($expr =~ /(exp ([\w\d]+))/) {
			my $exp = $1;
			my $val = exp($2);
			$expr =~ s/$exp/+$val/g;
		}

		# Convert hex to decimal
		while ($expr =~ /(hex2dec\s*([0-9A-Fa-f]+))/) {
			my $exp = $1;
			my $val = hex($2);
			$expr =~ s/$exp/+$val/g;
		}

		# Convert decimal to hex
		if ($expr =~ /^\s*(dec2hex\s*(\d+))\s*\?*/) {
			my $exp = $1;
			my $val = sprintf("%x", "$2");
			$expr =~ s/$exp/+$val/g;
		}

		# Logarithms
		my $E = exp(1);
		$expr =~ s/\be\b/$E/;

		while ($expr =~ /(log\s*((\d+\.?\d*)|\d*\.?\d+))\s*/) {
			my $exp = $1;
			my $res = $2;
			if ($res == 0) {
				$res = "Infinity";
			} else {
				$res = log($res);
			}
			$expr =~ s/$exp/+$res/g;
		}

		# Convert binary to decimal
		while ($expr =~ /(bin2dec ([01]+))/) {
			my $exp = $1;
			my $val = join ('', unpack ("B*", $2));
			$expr =~ s/$exp/+$val/g;
		}

		# Convert decimal to binary
		while ($expr =~ /(dec2bin (\d+))/) {
			my $exp = $1;
			my $val = join('', unpack('B*', pack('N', $2)));
			$val =~ s/^0+//;
			$expr =~ s/$exp/+$val/g;
		}

		# Replace words with symbols
		$expr =~ s/ to the / ** /g;
		$expr =~ s/\btimes\b/\*/g;
		$expr =~ s/\bdiv(ided by)? /\/ /g;
		$expr =~ s/\bover /\/ /g;
		$expr =~ s/\bsquared/\*\*2 /g;
		$expr =~ s/\bcubed/\*\*3 /g;
		$expr =~ s/\bto\s+(\d+)(r?st|nd|rd|th)?( power)?/\*\*$1 /ig;
		$expr =~ s/\bpercent of/*0.01*/ig;
		$expr =~ s/\bpercent/*0.01/ig;
		$expr =~ s/\% of\b/*0.01*/g;
		$expr =~ s/\%/*0.01/g;
		$expr =~ s/\bsquare root of (\d+)/$1 ** 0.5 /ig;
		$expr =~ s/\bcubed? root of (\d+)/$1 **(1.0\/3.0) /ig;
		$expr =~ s/ of / * /;

		# Check if we have a reasonable expression left over
		if (($expr =~ /^\s*[-\d*+\s()\/^\.\|\&\*\!]+\s*$/) && ($expr !~ /^\s*\(?\d+\.?\d*\)?\s*$/) && ($expr !~ /^\s*$/) && ($expr !~ /^\s*[( )]+\s*$/)) {
			my $result = eval($expr);

			return undef unless $result;

			if ($result =~ /^[-+\de\.]+$/) {
				$result =~ s/\.0+$//;
				$result =~ s/(\.\d+)000\d+/$1/;
				if (length($result) > 30) {
					$result = "a number with quite a few digits...";
				}
				return $result;
			}
		}
	}
}

1;
