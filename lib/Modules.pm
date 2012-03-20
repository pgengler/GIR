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
#     'actions'     => [ list of { 'priority' => <priority>, 'action' => <text to handle>, 'function' => <handler function> } ],
#     'private'     => [ list of { 'action'   => <text to handle>, 'function' => <handler function> } ],
#     'listeners'   => [ list of { 'priority' => <priority>, 'function' => <listener function> } ],
#     'help'        => [ list of { 'command'  => <command to provide help for>, 'function' => <help function> } ],
#     'nickchange'  => <callback function>,
#			'topicchange' => <callback function>,
#     'join'        => <callback function>,
#     'part'        => <callback function>,
#   },
#   ...
# }
my %registered;

# Keep a single list of actions, private handlers, listeners, and help functions
my (%actions, %private, %listeners);
our %help;
my %event_handlers = _empty_event_handlers();

# When set to a true value, suppresses calls to rebuild_registration_list. This is used to avoid
# calling that function multiple times during initialization without preventing it from being
# called during normal execution.
my $suppress_rebuild = 0;

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
	restart_thread_pool();
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
		do  => [ \&dispatch_t ]
	);
}

sub load_modules()
{
	# Unload any existing modules
	unload_modules();

	my $module_dir = $Bot::config->{'module_dir'};

	opendir(my $dir, $module_dir) or Bot::fatal_error('Unable to open the modules directory: %s', $!);
	my @files = readdir($dir);
	closedir($dir);

	my @modules = grep(/pm$/, @files);
	my %mod_info;

	my %blacklist = (
		map { ($_ => 1) } @{ $Bot::config->{'skip_modules'} || [ ] },
	);
	my $use_whitelist = scalar(@{ $Bot::config->{'load_modules'} || [ ] });
	my %whitelist = (
		map { ($_ => 1) } @{ $Bot::config->{'load_modules'} || [ ] },
	);

	foreach my $module (@modules) {
		# Remove ".pm" extension
		my $module_name = substr($module, 0, -3);

		# Check if module is on blacklist
		if (exists $blacklist{ $module_name }) {
			Bot::status("Skipping module '%s' because it's listed in 'skip_modules'", $module_name);
			next;
		}

		# Check if module is on whitelist (if it's being used)
		if (!$use_whitelist || exists $whitelist{ $module_name }) {
			load_module($module_name, 1, 1);
		} elsif ($use_whitelist) {
			Bot::status("Skipping module '%s' since it's not listed in 'load_modules'", $module_name);
		}
	}
	restart_thread_pool();
}

sub load_module($$$)
{
	my ($name, $suppress_restart, $auto) = @_;

	my $class = new RuntimeLoader('Modules::' . $name);

	$class->add_path($Bot::config->{'module_dir'} . '../');

	my $module = $class->load();

	unless ($module) {
		Bot::status("Failed to load module '%s': %s", $name, $@);
		$class->unload();
		return;
	}

	# If register() method returns -1, it means that it should not be loaded.
	# We call unload_module() to make sure the module doesn't leave any handlers running while claiming it shouldn't load.

	$suppress_rebuild = 1;
	my $ret = $module->register($auto) || 0;
	$suppress_rebuild = 0;

	if ($ret == -1) {
		Bot::status("Module '%s' requested to not be loaded", $name);
		unload_module($name, 1);
		return;
	}

	push @loaded_modules, $class;

	Bot::status('Loaded module %s', $name);

	rebuild_registration_list();
	# Only restart the thread pool when we load a specific module; when we're loading everything, don't restart the thread pool when each module is loaded
	restart_thread_pool() unless $suppress_restart;
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
	%event_handlers = _empty_event_handlers();

	restart_thread_pool();
}

sub unload_module($;$)
{
	my ($name, $silent) = @_;

	my $mod_name = ($name =~ /^Modules\:\:/) ? $name : 'Modules::' . $name;

	for (my $i = 0; $i < scalar(@loaded_modules); $i++) {
		my $class = $loaded_modules[$i];
		if ($class->name() eq $mod_name) {
			Bot::status("Unloading module '%s'", $name);

			# Remove from list of modules
			splice(@loaded_modules, $i, 1);

			# Remove handlers from this module
			delete $registered{ $mod_name };
			rebuild_registration_list();
			restart_thread_pool();

			# Unload
			$class->unload();

			return;
		}
	}

	Bot::status("Can't unload module '$name' because it isn't loaded", $name) unless $silent;
}

sub register_action($$;$)
{
	my ($action, $func, $priority) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	$priority ||= 1;

	Bot::debug("Registering handler for '%s' from '%s' module with priority %d", $action, $module, $priority);

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

	rebuild_registration_list() unless $suppress_rebuild;
}

sub unregister_action($)
{
	my $action = shift;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	Bot::debug("Unregistering handler for '%s' from '%s'", $action, $module);

	if (exists $registered{ $module }->{'actions'}) {
		my @actions = ( );
		foreach my $act (@{ $registered{ $module }->{'actions'} }) {
			push @actions, $act unless ($act->{'action'} eq $action);
		}
		@{ $registered{ $module }->{'actions'} } = @actions;
	}

	rebuild_registration_list();
	restart_thread_pool();
}

sub register_private($$)
{
	my ($action, $func) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	Bot::debug("Registering private handler for '%s' from '%s' module", $action, $module);

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

sub register_listener($$)
{
	my ($func, $priority) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	Bot::debug("Registering listener (priority %d) from '%s' module", $priority, $module);

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

sub register_help($$)
{
	my ($command, $func) = @_;

	return unless $command && $func;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	Bot::debug("Registering help for '%s' from '%s' module", $command, $module);

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

sub register_event($$)
{
	my ($event, $function) = @_;

	my @caller_info = caller;
	my $module      = $caller_info[0];

	unless (exists $event_handlers{ $event }) {
		Bot::error("%s: can't register handler for '%s' events: invalid event type", $module, $event);
		return;
	}

	Bot::debug("Registering %s handler from '%s' module", $event, $module);

	if (exists $registered{ $module }) {
		$registered{ $module }->{ $event } = $function;
	} else {
		$registered{ $module } = { $event => $function };
	}
}

sub rebuild_registration_list()
{
	# Reset to empty states
	%actions    = ( );
	%private    = ( );
	%help       = ( );
	%listeners  = ( );
	%event_handlers = _empty_event_handlers();

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
		foreach my $event (keys %event_handlers) {
			if (exists $registered{ $module }->{ $event }) {
				push @{ $event_handlers{ $event } }, $registered{ $module }->{ $event };
			}
		}
	}
}

sub event($$)
{
	my ($event, $params) = @_;

	Bot::debug("Modules::event called for event of type '%s'", $event);
	Bot::debug("Modules::event: There are %d handlers for '%s' events", scalar(@{ $event_handlers{ $event } }), $event);

	foreach my $callback (@{ $event_handlers{ $event } }) {
		$callback->($params);
	}
}

sub dispatch($)
{
	my $message = shift;

	$pool->add($message);
}

sub dispatch_t($)
{
	my $message = shift;

	my $result = process($message);

	if ($result && $result ne 'NOREPLY') {
		Bot::enqueue_say($message->where(), $result);
	}
}

sub process($;$)
{
	my ($message, $nests) = @_;
	$nests ||= 0;

	if ($message->message() =~ /^(.+?)?{{(.+)}}(.+?)?$/ && $nests < $Bot::config->{'max_nest'}) {
		my $pre  = $1 || '';
		my $nest = $2 || '';
		my $post = $3 || '';
		Bot::debug("Nested: pre: %s\ncommand: %s\npost: %s", $pre, $nest, $post);

		my $msg = new Message($message, { 'message' => $nest });
		my $result = process($msg, $nests + 1) || '';

		$result = '' if $result eq 'NOREPLY';
		$result = sprintf('%s%s%s', $pre, $result, $post);
		$message = new Message($message, { 'message' => $result });
	}


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
			} else {
				my $msg;
				if ($message->message() =~ /^$act(\!|\.|\?)*$/i) {
					$msg = new Message($message, { 'message' => '' });
				} elsif ($message->message() =~ /^$act\s+(.+?)$/i) {
					$msg = new Message($message, {
						'message' => $1,
					});
				}
				if ($msg) {
					$result = $action->{'function'}->($msg);
					return $result if $result;
				}
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
	Bot::debug('Cleaning up modules...');

	# Wait for threads to finish before exiting
	if ($pool) {
		$pool->join();
	}
}

# Get a hash structure for event handlers with no stored data
sub _empty_event_handlers()
{
	return (
		'join'         => [ ],
		'mynickchange' => [ ],
		'nickchange'   => [ ],
		'part'         => [ ],
		'topicchange'  => [ ],
	);
}

1;

