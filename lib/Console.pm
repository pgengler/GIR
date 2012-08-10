package Console;

use strict;

use Command;

##############
## CONSOLE INPUT
##############
sub console()
{
	$SIG{'TERM'} = sub { $Bot::bot->kill('SIGTERM'); threads->exit(); };
	$SIG{'INT'} = sub { $Bot::bot->kill('SIGTERM'); threads->exit(); };

	unless ($Bot::no_console) {
		while (<>) {
			console_parse($_);
			threads->self()->yield();
		}
	} else {
		while (1) {
			threads->self()->yield();
		}
	}
}

sub console_parse($)
{
	my $str = shift;

	my $command = Command::parse($str);

	push @Bot::commands, $command;

	if ($command =~ /^quit/) {
		$Bot::bot->kill('SIGTERM');
		threads->exit();
	}

	if (scalar(@Bot::commands) > 0) {
		$Bot::bot->kill('SIGUSR1');
	}
}


1;
