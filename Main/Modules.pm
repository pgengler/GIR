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

# @loaded_modules is a collection of RuntimeLoader objects
my @loaded_modules;

# Keep track of all registered handlers and listeners.
# This has is structured as follows:
# %registered = (
#   '<module name>' => {
#     'actions'   => [ list of { 'action'   => <text to handle>, 'function' => <handler function> } ],
#     'private'   => [ list of { 'action'   => <text to handle>, 'function' => <handler function> } ],
#     'listeners' => [ list of { 'priority' => <priority>, 'function' => <listener function> } ],
#     'help'      => [ list of { 'command'  => <command to provide help for>, 'function' => <help function> } ]
#   },
#   ...
# }
my %registered;


# Keep a single list of actions, private handlers, listeners, and help functions
my (%actions, %private, %listeners);
our %help;

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

	&Bot::status("Loaded module $name");

	$module->register();

	push @loaded_modules, $class;

	&rebuild_registration_list();
}

sub unload_modules()
{
	while (my $class = shift(@loaded_modules)) {
		$class->unload();
	}

	# Clear lists of handlers
	%registered     = ( );

	%actions        = ( );
	%private        = ( );	
	%listeners      = ( );
	%help           = ( );
}

sub unload_module()
{
	my $name = shift;

	my $mod_name = ($name =~ /^Modules\:\:/) ? $name : 'Modules::' . $name;

	for (my $i = 0; $i < scalar(@loaded_modules); $i++) {
		my $class = $loaded_modules[$i];
		if ($class->name() eq $mod_name) {
			&Bot::status("Unloading module '$name'");

			# Remove from list of modules
			splice(@loaded_modules, $i, 1);

			# Remove handlers from this module
			delete $registered{ $mod_name };
			&rebuild_registration_list();

			# Unload
			$class->unload();

			return;
		}
	}

	&Bot::status("Module '$name' is not loaded!");
}

sub register_action()
{
	my ($action, $func) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	&Bot::status("Registering handler for '$action' from '$module' module") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		push @{ $registered{ $module }->{'actions'} }, {
			'action'   => $action,
			'function' => $func
		};
	} else {
		$registered{ $module } = {
			'actions' => [
				{
					'action'   => $action,
					'function' => $func
				}
			]
		};
	}
}

sub register_private()
{
	my ($action, $func) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	&Bot::status("Registering private handler for '$action' from '$module' module") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		push @{ $registered{ $module }->{'private'} }, {
			'action'   => $action,
			'function' => $func
		};
	} else {
		$registered{ $module } = {
			'private' => [
				{
					'action'   => $action,
					'function' => $func
				}
			]
		};
	}
}

sub register_listener()
{
	my ($func, $priority) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	&Bot::status("Registering listener (priority $priority) from '$module' module") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		push @{ $registered{ $module }->{'listeners'} }, {
			'priority' => $priority,
			'function' => $func
		};
	} else {
		$registered{ $module } = {
			'listeners' => [
				{
					'priority' => $priority,
					'function' => $func
				}
			]
		};
	}
}

sub register_help()
{
	my ($command, $func) = @_;

	return unless $command && $func;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	&Bot::status("Registering help for '$command' from '$module' module") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		push @{ $registered{ $module }->{'help'} }, {
			'command'  => $command,
			'function' => $func
		};
	} else {
		$registered{ $module } = {
			'help' => [
				{
					'command'  => $command,
					'function' => $func
				}
			]
		};
	}
}

sub rebuild_registration_list()
{
	# Reset to empty states
	%actions   = ( );
	%private   = ( );
	%help      = ( );
	%listeners = ( );

	# Now, repopulate from registered items
	foreach my $module (keys %registered) {
		foreach my $action (@{ $registered{ $module }->{'actions'} }) {
			$actions{ $action->{'action'} } = $action->{'function'};
		}
		foreach my $private (@{ $registered{ $module }->{'private'} }) {
			$private{ $private->{'action'} } = $private->{'function'};
		}
		foreach my $help (@{ $registered{ $module }->{'help'} }) {
			$help{ $help->{'command'} } = $help->{'function'};
		}
		foreach my $listener (@{ $registered{ $module }->{'listeners'} }) {
			push @{ $listeners{ $listener->{'priority'} } }, $listener->{'function'};			
		}
	}
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

