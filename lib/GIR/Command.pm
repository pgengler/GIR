package GIR::Command;

use strict;

sub parse
{
	my ($string) = @_;

	chomp $string;

	# For now, nothing fancy, just some simple string matches
	if ($string =~ /^quit(\s+(.+))?$/) {
		return _command_string('quit', $2);
	} elsif ($string =~ /^reload(\s+(.+))?\s*$/) {
		return _command_string('reload', $2);
	} elsif ($string =~ /^unload\s+(.+)\s*$/) {
		return _command_string('unload', $1);
	} elsif ($string =~ /^load\s+(.+)\s*$/) {
		return _command_string('load', $1);
	} elsif ($string =~ /^list modules/) {
		return _command_string('list modules');
	} elsif ($string =~ /^\s*part\s+(.+?)(\s+(.+))?$/i) {
		return _command_string('part', $1, $3);
	} elsif ($string =~ /^\s*join\s+(.+)$/i) {
		return _command_string('join', $1);
	} elsif ($string =~ /^\s*say\s+(.+?)\s+(.+)$/i) {
		return _command_string('say', $1, $2);
	} elsif ($string =~ /^\s*action\s+(.+)\s+(.+)$/i) {
		return _command_string('action', $1, $2);
	} elsif ($string =~ /^\s*discon(nect)?(\s+(.+))?$/i) {
		return _command_string('discon', $3);
	} elsif ($string =~ /^\s*connect\s*$/i) {
		return _command_string('connect');
	} elsif ($string =~ /^\s*nick\s+(.+)$/) {
		return _command_string('nick', $1);
	} elsif ($string =~ /^\s*debug\s+(on|off)\s*$/) {
		return _command_string('debug', $1);
	}

	GIR::Bot::status("Unrecognized command '%s'", $string);
}

sub _command_string
{
	my ($command, @parameters) = @_;

	if (scalar(@parameters) == 0) {
		return $command;
	}

	return join('||', map { $_ || '' } ($command, @parameters));
}

1;
