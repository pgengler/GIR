package Console;

use strict;

##############
## CONSOLE INPUT
##############
sub console()
{
	$SIG{'TERM'} = sub { $Bot::bot->kill('SIGTERM'); threads->exit(); };
	$SIG{'INT'} = sub { $Bot::bot->kill('SIGTERM'); threads->exit(); };

	unless ($Bot::no_console) {
		while (<>) {
			&console_parse($_);
			threads->self()->yield();
		}
	} else {
		while (1) {
			threads->self()->yield();
		}
	}
}

sub console_parse()
{
	my $str = shift;

	chomp $str;

	# For now, nothing fancy, just some simple string matches
	if ($str =~ /^quit(\s+(.+))?$/) {
		&Bot::status("Shutting down");
		if ($2) {
			push @Bot::commands, "quit||$2";
		}
		$Bot::bot->kill('SIGTERM');
		threads->exit();
	} elsif ($str =~ /^reload(\s+(.+))?\s*$/) {
		push @Bot::commands, "reload||" . ($2 || '');
	} elsif ($str =~ /^unload\s+(.+)\s*$/) {
		push @Bot::commands, "unload||$1";
	} elsif ($str =~ /^load\s+(.+)\s*$/) {
		push @Bot::commands, "load||$1";
	} elsif ($str =~ /^\s*part\s+(.+?)(\s+(.+))?$/i) {
		push @Bot::commands, "part||$1||$3;
	} elsif ($str =~ /^\s*join\s+(.+)$/i) {
		push @Bot::commands, "join||$1";
	} elsif ($str =~ /^\s*say\s+(.+?)\s+(.+)$/i) {
		push @Bot::commands, "say||$1||$2";
	} elsif ($str =~ /^\s*action\s+(.+)\s+(.+)$/i) {
		push @Bot::commands, "action||$1||$2";
	} elsif ($str =~ /^\s*discon(nect)?(\s+(.+))?$/i) {
		my $reason = $3 || $1 || '';
		push @Bot::commands, "discon||$reason";
	} elsif ($str =~ /^\s*connect\s*$/i) {
		push @Bot::commands, "connect||";
	} elsif ($str =~ /^\s*nick\s+(.+)$/) {
		push @Bot::commands, "nick||$1";
	} elsif ($str =~ /^\s*debug\s+(on|off)\s*$/) {
		push @Bot::commands, "debug||$1";
	} else {
		&Bot::status("Unrecognized command");
	}

	if (scalar(@Bot::commands) > 0) {
		$Bot::bot->kill('SIGUSR1');
	}
}


1;
