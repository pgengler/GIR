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
use Thread::Pool::Simple;
use RuntimeLoader;

#######
## GLOBALS
#######

# Thread pool
my $pool;

# @loaded_modules is a collection of RuntimeLoader objects
my @loaded_modules;

# Keep track of all registered handlers and listeners.
# This has is structured as follows:
# %registered = (
#   '<module name>' => {
#     'actions'   => [ list of { 'priority' => <priority>, 'action' => <text to handle>, 'function' => <handler function> } ],
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
## Listener functions and action handlers are both registered with 'priority'
## values. For actions, this must be a positive integer; for listeners, this
## can also be the special value '-1'. A listener registered with -1 priority
## is called before any action handlers or other listeners.
## After the 'always' listeners (-1 priority) are called, if none indicated
## that processing should stop then actions are tried, starting with higher
## priorities and working down. After that come the 'private' actions,
## followed by the other listeners (in descending order of priority).
##
## No guarantees are made about the order of execution for multiple listeners
## or actions with the same priority value.
#######

#######
## FUNCTIONS
#######
sub init()
{
	&restart_thread_pool();
}

sub restart_thread_pool()
{
	if ($pool) {
		# If we have an existing pool, wait for its threads to complete
		$pool->join();
		# Then destroy the pool
		undef $pool;
	}
	# Create a new pool
	$pool = new Thread::Pool::Simple(
		min => 5,
		max => 10,
		do  => [\&dispatch_t]
	);
}

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

		&load_module($module_name, 1);
	}
	&restart_thread_pool();
}

sub load_module()
{
	my ($name, $suppress_restart) = @_;

	my $class = new RuntimeLoader('Modules::' . $name);

	$class->add_path($Bot::config->{'module_dir'} . '../');

	my $module = $class->load();

	unless ($module) {
		&Bot::status("Failed to load module '$name': $@");
		$class->unload();
		return;
	}

	&Bot::status("Loaded module $name");

	$module->register();

	push @loaded_modules, $class;

	&rebuild_registration_list();
	# Only restart the thread pool when we load a specific module; when we're loading everything, don't restart the thread pool when each module is loaded
	&restart_thread_pool() unless $suppress_restart;
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

	&restart_thread_pool();
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
			&restart_thread_pool();

			# Unload
			$class->unload();

			return;
		}
	}

	&Bot::status("Module '$name' is not loaded!");
}

sub register_action()
{
	my ($action, $func, $priority) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	$priority ||= 1;

	&Bot::status("Registering handler for '$action' from '$module' module with priority $priority") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		push @{ $registered{ $module }->{'actions'} }, {
			'action'   => $action,
			'priority' => $priority,
			'function' => $func
		};
	} else {
		$registered{ $module } = {
			'actions' => [
				{
					'action'   => $action,
					'priority' => $priority,
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
			push @{ $actions{ $action->{'priority'} } }, {
				'action'   => $action->{'action'},
				'function' => $action->{'function'}
			};
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

	$pool->add($type, $user, $message, $where, $addressed);
}

sub dispatch_t()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	my $result = &process($type, $user, $message, $where, $addressed);

	if ($result && $result ne 'NOREPLY') {
		&Bot::enqueue_say($where, $result);
	}
}

sub process()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Figure out if the message matches anything
	## Sort by length to start with the longest
	my @private = sort { length($b) <=> length($a) } keys %private;

	my $result = '';

	foreach my $listener (@{ $listeners{-1} }) {
		$listener->($type, $user, $message, $where, $addressed);
	}

	foreach my $priority (sort { $b <=> $a } keys %actions) {
		foreach my $action (@{ $actions{ $priority } }) {
			my $act = $action->{'action'};
			if ($message =~ /^$act(\!|\.|\?)*$/i || $message =~ /^$act\s+(.+?)$/i) {
				$result = $action->{'function'}->($type, $user, $1, $where, $addressed);
				return $result if $result;
			} elsif ($act =~ /REGEXP\:(.+)$/) {
				my $match = $1;
				if ($message =~ /$match/i) {
					$result = $action->{'function'}->($type, $user, $message, $where, $addressed);
					return $result if $result;
				}
			}

		}
	}

	if ($type eq 'private') {
		foreach my $private (@private) {
			if ($message =~ /^$private(\!|\.|\?)*$/i || $message =~ /^$private\s+(.+)$/i) {
				$result = $private{ $private }->($type, $user, $1, $where, $addressed);
				return $result if $result;
			} elsif ($private =~ /^REGEXP\:(.+)$/) {
				my $match = $1;
				if ($message =~ /$match/i) {
					$result = $private{ $private }->($type, $user, $message, $where, $addressed);
					return $result if $result;
				}
			}
		}
	}

	foreach my $priority (sort { $b <=> $a } keys %listeners) {
		foreach my $listener (@{ $listeners{ $priority } }) {
			$result = $listener->($type, $user, $message, $where, $addressed);
			return $result if $result;
		}
	}
}

1;

