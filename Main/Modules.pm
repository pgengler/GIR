package Modules;

#######
## PERL SETUP
#######
use strict;
use threads;
use threads::shared;

#######
## GLOBALS
#######
my %actions;
my %private;
my %listeners;

our %help_functions;

#######
## NOTES
#######
## Listener functions are registered with a 'priority' value. If this value is
## -1, the listener is always called, and this happens before any of the
## registered actions are tried. Otherwise, the actions are tried first and if
## none generated a response or indicated that processing should stop, the
## other listeners are tried in descending order by priority. No guarantees
## are provided about the order of execution for multiple listeners with the
## same priority value.
#######

#######
## FUNCTIONS
#######
sub load_modules()
{
	my $module_dir = $Bot::config->{'module_dir'};

	opendir(DIR, $module_dir) or &Bot::error('Unable to open the modules directory: ' . $!);
	my @files = readdir(DIR);
	closedir(DIR);

	my @modules = grep(/pm$/, @files);
	my %mod_info;

	foreach my $module (@modules) {
		# Remove ".pm" extension
		my $module_name = substr($module, 0, -3);
		my $code = qq~
require "$module_dir/$module";
my \$mod = new Modules::$module_name;
\$mod->register();
		~;
		eval($code);
		die $@ if $@;
	}
}

sub register_action()
{
	my ($action, $func) = @_;

	$actions{ $action } = $func;
}

sub register_private()
{
	my ($action, $func) = @_;

	$private{ $action } = $func;
}

sub register_listener()
{
	my ($func, $priority) = @_;

	push @{ $listeners{ $priority } }, $func;
}

sub register_help()
{
	my ($command, $func) = @_;

	return unless $command && $func;

	if ($help_functions{ $command }) {
		&Bot::status("WARNING: Registering duplicate help handler for '$command'");
	}

	$help_functions{ $command } = $func;
}

sub dispatch()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	my $dispatcher = threads->create('dispatch_t', $type, $user, $message, $where, $addressed);
	$dispatcher->detach();
}

sub dispatch_t()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Figure out if the message matches anything
	## Sort by length to start with the longest
	my @actions = sort { length($b) <=> length($a) } keys %actions;
	my @private = sort { length($b) <=> length($a) } keys %private;

	my $result = '';

	foreach my $listener (@{ $listeners{-1} }) {
		$listener->($type, $user, $message, $where, $addressed);
	}

	foreach my $action (@actions) {
		if ($message =~ /^$action(\!|\.|\?)*$/i || $message =~ /^$action\s+(.+)$/i) {
			$result = $actions{ $action }->($type, $user, $1, $where, $addressed);
			if ($result && $result ne 'NOREPLY') {
				&Bot::enqueue_say($where, $result);
			}
			if ($result) {
				return;
			}
		} elsif ($action =~ /^REGEXP\:(.+)$/) {
			my $match = $1;
			if ($message =~ /$match/i) {
				$result = $actions{ $action }->($type, $user, $message, $where, $addressed);
				if ($result && $result ne 'NOREPLY') {
					&Bot::enqueue_say($where, $result);
				}
				if ($result) {
					return;
				}
			}
		}
	}

	if ($type eq 'private') {
		foreach my $private (@private) {
			if ($message =~ /^$private(\!|\.|\?)*$/i || $message =~ /^$private\s+(.+)$/i) {
				$result = $private{ $private }->($type, $user, $1, $where, $addressed);
				if ($result && $result ne 'NOREPLY') {
					&Bot::enqueue_say($where, $result);
				}
				if ($result) {
					return;
				}
			} elsif ($private =~ /^REGEXP\:(.+)$/) {
				my $match = $1;
				if ($message =~ /$match/i) {
					$result = $private{ $private }->($type, $user, $message, $where, $addressed);
					if ($result && $result ne 'NOREPLY') {
						&Bot::enqueue_say($where, $result);
					}
					if ($result) {
						return;
					}
				}
			}
		}
	}

	foreach my $priority (sort { $b <=> $a } keys %listeners) {
		foreach my $listener (@{ $listeners{ $priority } }) {
			$result = $listener->($type, $user, $message, $where, $addressed);
			if ($result && $result ne 'NOREPLY') {
				&Bot::enqueue_say($where, $result);
			}
			if ($result) {
				return;
			}
		}
	}
}

1;

