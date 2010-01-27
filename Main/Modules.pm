package Modules;

#######
## PERL SETUP
#######
use strict;
use threads;
use threads::shared;

#######
## INCLUDES
#######
use RuntimeLoader;

#######
## GLOBALS
#######
my @loaded_modules;
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
	# Unload any existing modules
	&unload_modules();

	my $module_dir = $Bot::config->{'module_dir'};

	opendir(DIR, $module_dir) or &Bot::error('Unable to open the modules directory: ' . $!);
	my @files = readdir(DIR);
	closedir(DIR);

	my @modules = grep(/pm$/, @files);
	my %mod_info;

	foreach my $module (@modules) {
		# Remove ".pm" extension
		my $module_name = substr($module, 0, -3);

		&load_module($module_name);
	}
}

sub load_module()
{
	my $name = shift;

	my $class = new RuntimeLoader('Modules::' . $name);

	$class->add_path($Bot::config->{'module_dir'} . '../');

	my $module = $class->load();

	unless ($module) {
		die "Error loading class: $@";
	}

	$module->register();

	push @loaded_modules, $class;
}

sub unload_modules()
{
	while (my $class = shift(@loaded_modules)) {
		$class->unload();
	}

	# Clear lists of handlers
	%actions        = ( );
	%private        = ( );	
	%listeners      = ( );
	%help_functions = ( );
}

sub register_action()
{
	my ($action, $func) = @_;

	my @mod = caller;
	&Bot::status("Registering handler for '$action' from '$mod[0]' module") if $Bot::config->{'debug'};

	$actions{ $action } = $func;
}

sub register_private()
{
	my ($action, $func) = @_;

	my @mod = caller;
	&Bot::status("Registering private handler for '$action' from '$mod[0]' module") if $Bot::config->{'debug'};

	$private{ $action } = $func;
}

sub register_listener()
{
	my ($func, $priority) = @_;

	my @mod = caller;
	&Bot::status("Registering listener (priority $priority) from '$mod[0]' module") if $Bot::config->{'debug'};

	push @{ $listeners{ $priority } }, $func;
}

sub register_help()
{
	my ($command, $func) = @_;

	return unless $command && $func;

	my @mod = caller;
	&Bot::status("Registering help for '$command' from '$mod[0]' module") if $Bot::config->{'debug'};

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

