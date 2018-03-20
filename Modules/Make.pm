package Modules::Make;

use strict;

sub register
{
	GIR::Modules->register_action(qr/^make\s+(\w+?)(\s|$)/, \&Modules::Make::fake_make_output);
}

sub fake_make_output
{
	my $message = shift;

    if ($message->message =~ /^make\s+(\w+?)(\s|$)/) {
		my $command = $1;
        return "make: *** No rule to make target `${command}'.  Stop.";
	}
}

print fake_make_output("make hello");
1;
