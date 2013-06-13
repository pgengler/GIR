package GIR::Module;

use strict;

use GIR::Util;

sub new
{
	my $class = shift;
	{
		no strict 'refs';
		foreach my $function (@GIR::Util::EXPORT) {
			*{"${class}::${function}"} = \&{"GIR::Util::${function}"};
		}
	}
	bless { }, $class;
}

1;
