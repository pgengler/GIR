package Modules::Git;

use strict;

sub register
{
	GIR::Modules->register_action(qr/^git\s+(\w+?)(\s|$)/, \&Modules::Git::fake_git_output);
}

sub fake_git_output
{
	my $message = shift;

	if ($message->message =~ /^git\s+(\w+?|--help)(\s|$)/) {
		my $command = $1;
		if ($command eq 'clone') {
			return "ERROR: Repository not found.\nfatal: Could not read from remote repository.\n\nPlease make sure you have the correct access rights\nand the repository exists.";
		} elsif ($command eq 'init') {
			return '/home/gir/.git: Permission denied';
		} elsif ($command eq 'add' || $command eq 'bisect' || $command eq 'branch' || $command eq 'checkout' || $command eq 'commit' || $command eq 'diff' || $command eq 'fetch' || $command eq 'pull' || $command eq 'push' || $command eq 'merge' || $command eq 'mv' || $command eq 'rebase' || $command eq 'reset' || $command eq 'rm' || $command eq 'show') {
			return 'fatal: Not a git repository (or any of the parent directories): .git';
		} elsif ($command eq '--help') {
			return "Here's a tip: use a Git client instead of an IRC bot.";
		}
		return "git: '${command}' is not a git command. See 'git --help'.";
	}
}

1;
