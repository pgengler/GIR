package Modules::Git;

use strict;

use POSIX qw/ strftime /;

use constant GIT_REGEXP => qr/^git\s+([\w-]+?|--help)(\s|$)/;

my $VALID_COMMANDS = [
	'add',
	'bisect',
	'branch',
	'checkout',
	'cherry-pick',
	'commit',
	'config',
	'diff',
	'fetch',
	'grep',
	'log',
	'pull',
	'push',
	'merge',
	'mv',
	'rebase',
	'remote',
	'reset',
	'restore',
	'rm',
	'show',
	'sparse-checkout',
	'status',
	'switch',
	'tag',
];

sub register
{
	GIR::Modules->register_action(GIT_REGEXP, \&Modules::Git::fake_git_output);
}

sub is_valid_command
{
	my $command = shift;

	return $command ~~ @$VALID_COMMANDS;
}

sub fake_git_output
{
	my $message = shift;

	if ($message->message =~ GIT_REGEXP) {
		my $command = $1;
		if ($command eq 'clone') {
			return "ERROR: Repository not found.\nfatal: Could not read from remote repository.\n\nPlease make sure you have the correct access rights\nand the repository exists.";
		} elsif ($command eq 'init') {
			return '/home/gir/.git: Permission denied';
    } elsif ($command eq 'blame') {
			my $who = $message->from;
			my $datetime = strftime('%Y-%m-%d %H:%M:%S %Z', gmtime());
			return "1234abc\t${who}\t${datetime}\t1) I can't tell IRC and my terminal apart.";
		} elsif ($command eq 'config') {
			return 'Segmentation fault';
		} elsif (&is_valid_command($command)) {
			return 'fatal: Not a git repository (or any of the parent directories): .git';
		} elsif ($command eq '--help') {
			return "Here's a tip: use a Git client instead of an IRC bot.";
		}
		return "git: '${command}' is not a git command. See 'git --help'.";
	}
}

1;
