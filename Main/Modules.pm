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

use Message;
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
#     'actions'    => [ list of { 'priority' => <priority>, 'action' => <text to handle>, 'function' => <handler function> } ],
#     'private'    => [ list of { 'action'   => <text to handle>, 'function' => <handler function> } ],
#     'listeners'  => [ list of { 'priority' => <priority>, 'function' => <listener function> } ],
#     'help'       => [ list of { 'command'  => <command to provide help for>, 'function' => <help function> } ],
#     'nickchange' => <callback function>,
#   },
#   ...
# }
my %registered;


# Keep a single list of actions, private handlers, listeners, and help functions
my (%actions, %private, %listeners);
our %help;
my @nickchange;

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

		&load_module($module_name, 1, 1);
	}
	&restart_thread_pool();
}

sub load_module()
{
	my ($name, $suppress_restart, $auto) = @_;

	my $class = new RuntimeLoader('Modules::' . $name);

	$class->add_path($Bot::config->{'module_dir'} . '../');

	my $module = $class->load();

	unless ($module) {
		&Bot::status("Failed to load module '$name': $@");
		$class->unload();
		return;
	}

	&Bot::status("Loaded module $name");

	# If register() method returns -1, it means that it should not be loaded.
	# We call unload_module() to make sure the module doesn't leave any handlers running while claiming it shouldn't load.
	my $ret = $module->register($auto) || 0;

	if ($ret == -1) {
		&Bot::status("Module '$name' requested to not be loaded.");
		&unload_module($name, 1);
		return;
	}

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
	my ($name, $silent) = @_;

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

	&Bot::status("Module '$name' is not loaded!") unless $silent;
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

sub register_nickchange()
{
	my $func = shift;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	&Bot::status("Registering nickchange handler from '$module' module") if $Bot::config->{'debug'};

	if (exists $registered{ $module }) {
		$registered{ $module }->{'nickchange'} = $func;
	} else {
		$registered{ $module } = { 'nickchange' => $func };
	}
}

sub rebuild_registration_list()
{
	# Reset to empty states
	%actions    = ( );
	%private    = ( );
	%help       = ( );
	%listeners  = ( );
	@nickchange = ( );

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
		if (exists $registered{ $module }->{'nickchange'}) {
			push @nickchange, $registered{ $module }->{'nickchange'};
		}
	}
}

sub nick_changed()
{
	my $params = shift;

	foreach my $callback (@nickchange) {
		$callback->($params);
	}
}

sub dispatch()
{
	my $message = shift;

	$pool->add($message);
}

sub dispatch_t()
{
	my $message = shift;

	my $result = &process($message);

	if ($result && $result ne 'NOREPLY') {
		&Bot::enqueue_say($message->where(), $result);
	}
}

sub process()
{
	my $message = shift;

	# Figure out if the message matches anything
	## Sort by length to start with the longest
	my @private = sort { length($b) <=> length($a) } keys %private;

	my $result = '';

	foreach my $listener (@{ $listeners{-1} }) {
		$listener->($message);
	}

	foreach my $priority (sort { $b <=> $a } keys %actions) {
		foreach my $action (@{ $actions{ $priority } }) {
			my $act = $action->{'action'};
			if (ref($act) eq 'Regexp') {
				if ($message->message() =~ $act) {
					$result = $action->{'function'}->($message);
					return $result if $result;
				}
			} elsif ($message->message() =~ /^$act(\!|\.|\?)*$/i || $message->message() =~ /^$act\s+(.+?)$/i) {
				my $msg = new Message($message, {
					'message' => $1,
				});
				$result = $action->{'function'}->($msg);
				return $result if $result;
			}
		}
	}

	unless ($message->is_public()) {
		foreach my $private (@private) {
			if (ref($private) eq 'Regexp') {
				if ($message->message() =~ $private) {
					$result = $private{ $private }->($message);
					return $result if $result;
				}
			} elsif ($message->message() =~ /^$private(\!|\.|\?)*$/i || $message->message() =~ /^$private\s+(.+)$/i) {
				my $msg = new Message($message, {
					'message'  => $1,
				});
				$result = $private{ $private }->($msg);
				return $result if $result;
			}
		}
	}

	foreach my $priority (sort { $b <=> $a } keys %listeners) {
		foreach my $listener (@{ $listeners{ $priority } }) {
			$result = $listener->($message);
			return $result if $result;
		}
	}
}

sub shutdown()
{
	&Bot::status("Cleaning up modules...") if $Bot::config->{'debug'};

	# Wait for threads to finish before exiting
	if ($pool) {
		$pool->join();
	}
}

1;

