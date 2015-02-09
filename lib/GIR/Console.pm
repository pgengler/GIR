package GIR::Console;

use strict;

use GIR::Command;

##############
## CONSOLE INPUT
##############
sub console
{
	$SIG{'TERM'} = sub { $GIR::Bot::bot->kill('SIGTERM'); threads->exit; };
	$SIG{'INT'} = sub { $GIR::Bot::bot->kill('SIGTERM'); threads->exit; };

	unless ($GIR::Bot::no_console) {
		while (<>) {
			console_parse($_);
			threads->self->yield;
		}
	} else {
		while (1) {
			threads->self->yield;
		}
	}
}

sub console_parse
{
	my $str = shift;

	my $command = GIR::Command->parse($str);

	push @GIR::Bot::commands, $command;

	if ($command =~ /^quit/) {
		$GIR::Bot::bot->kill('SIGTERM');
		threads->exit;
	}

	if (scalar(@GIR::Bot::commands) > 0) {
		$GIR::Bot::bot->kill('SIGUSR1');
	}
}


1;
