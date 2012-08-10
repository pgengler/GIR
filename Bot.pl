#!/usr/bin/perl
#!/opt/perl-thread/bin/perl -w

use strict;
use threads;
use threads::shared;
use lib qw/ lib /;

use File::Copy;
use File::Spec;
use Getopt::Long;
use IO::Socket::UNIX;
use Net::IRC;
use POSIX;
use Text::Wrap;
use YAML;

use Console;
use Modules;

package Bot;

use constant {
	false => 0,
	true  => 1
};

#######
## GLOBAL VARS
#######
our $connected :shared  = false;
our $running :shared    = true;
our $config_file        = 'config';
our $config             = undef;
our $irc                = undef;
our $connection         = undef;
our $no_console         = false;
my  $nick_retries       = 0;
my  %ignores :shared;
our @commands :shared;
my %channels;

#######
## GLOBAL SETUP
#######

# Parse command-line arguments
Getopt::Long::GetOptions(
	'silent'   => \$no_console,
	'config=s' => \$config_file
);

# Load configuration
$config = load_config($config_file);

# Perform pre-loading initialization for module stuff
Modules::init();

# Unbuffer standard output
select(STDOUT);
$| = 1;

# Intercept Ctrl+C
$SIG{'INT'} = \&shutdown;

# Load ignore list
load_ignore();

# Load extras
Modules::load_modules();

#######
## START IRCING
#######

our $bot     = threads->create('bot');
our $console = threads->create('Console::console');

$bot->join();
$console->join();

sub get_command_socket()
{
	my $temp_directory = File::Spec->tmpdir();
	my $socket_path    = File::Spec->catfile($temp_directory, 'ircbot');

	if (-S $socket_path) {
		unlink($socket_path);
	}

	my $server = new IO::Socket::UNIX(
		'Listen' => Socket::SOMAXCONN,
		'Local'  => $socket_path,
		'Type'   => Socket::SOCK_STREAM,
	);

	return $server;
}

sub bot()
{
	$SIG{'USR1'} = \&bot_command;
	$SIG{'TERM'} = \&bot_shutdown;
	$SIG{'INT'}  = sub { bot_shutdown(); $console->kill('SIGINT'); threads->exit(); };

	while (1) {
		# Reset list of joined channels
		%channels = ();

		# Connect to the server
		Bot::connect();

		# Set up event handlers
		$connection->add_global_handler('001', \&on_connect);
		$connection->add_handler('join', \&on_join);
		$connection->add_handler('part', \&on_part);
		$connection->add_handler('topic', \&on_topic);
		$connection->add_handler('kick', \&on_kick);
		$connection->add_handler('invite', \&on_invite);
		$connection->add_handler('public', \&message);
		$connection->add_handler('msg', \&message);
		$connection->add_handler('caction', \&handle_action);
		$connection->add_handler('notice', \&on_notice);
		$connection->add_handler('disconnect', \&on_disconnect);
		$connection->add_handler('mode', \&on_mode);
		$connection->add_handler('nick', \&on_nick_change);
		$connection->add_handler('quit', \&on_quit);
		$connection->add_handler('error', \&on_error);
		$connection->add_handler('nicknameinuse', \&nick_in_use);
		$connection->add_handler('bannedfromchan', \&banned_from_channel);
		$connection->add_handler('snotice', \&on_server_notice);

		$irc->timeout(.25);

		my $command_socket = get_command_socket();
		$irc->addfh($command_socket, sub {
			my $server = shift;
			my $client = $server->accept();
			Bot::debug('Received new connection via UNIX socket');
			$irc->addfh($client, sub {
				my $client = shift;
				sysread($client, my $data, 1024);
				Bot::debug("Received command '%s' via UNIX socket", $data);
				my $command = Command::parse($data);
				if ($command) {
					push @commands, $command;
				}
				$client->shutdown(2);
				$irc->removefh($client);
			});
		});

		while ($connection->connected()) {
			$irc->do_one_loop();
			if (scalar(@commands) > 0) {
				bot_command();
			}
		}
	}
}

#######
## LOAD CONFIG
#######
sub load_config($)
{
	my $config_file = shift;
	$config_file ||= 'config';

	my $config;

	eval {
		open(my $file, '<', $config_file || 'config') or Bot::fatal_error("Can't open config file '%s': %s", $config_file, $!);
		$config = YAML::LoadFile($file);
		close($file);
	};
	if ($@) {
		Bot::fatal_error("Failed to read config file; you probably have an error in your YAML syntax (did you use tabs instead of spaces?)");
	}

	# 'config_nick' represents the nickname as entered in the config file, while 'nick' represents the actual name in use
	$config->{'config_nick'} ||= $config->{'nick'};

	return $config;
}

#######
## ERROR HANDLER
#######
sub on_error($$)
{
	my ($conn, $event) = @_;

	print "on_error\n";
	use Data::Dumper;
	print Dumper($event);
	print "\n------------\n";
}

#######
## CONNECT
#######
sub connect()
{
	status('Connecting to port %d of server %s...', $config->{'server'}->{'port'}, $config->{'server'}->{'host'});

	$irc = new Net::IRC;
	$irc->debug($config->{'debug'} ? true : false);
	$irc->timeout(5);
	$connection = $irc->newconn(
		Nick     => $config->{'nick'},
		Server   => $config->{'server'}->{'host'},
		Port     => $config->{'server'}->{'port'},
		Ircname  => $config->{'name'} || $config->{'nick'},
		Username => $config->{'username'} || $config->{'nick'}
	);

	if (!$connection) {
		fatal_error('Unable to connect to server.');
	}
}

#######
## JOIN CHANNEL
#######
sub join_chan($$)
{
	my ($conn, $channel) = @_;

	if (exists $channels{ $channel }) {
		status("I'm already in %s!", $channel);
		return;
	}

	status('Joining %s...', $channel);

	$conn->join($channel);
}

#######
## ON CONNECT
#######
sub on_connect($$)
{
	my ($conn, $event) = @_;

	status('Joining channels...');

	foreach my $channel (@{ $config->{'channels'}->{'join'} }) {
		join_chan($conn, $channel);
	}
}

#######
## SHUTDOWN
#######
sub shutdown()
{
	status('Shutting down...');

	$bot->kill('SIGTERM') if $bot;
	$console->kill('SIGTERM') if $console;

	# End threads
	threads->exit();
}

sub bot_shutdown()
{
	status('Bot thread is shutting down...');

	Modules::shutdown();

	# Look for a quit message
	my $message = "Leaving";
	foreach my $command (@commands) {
		my ($command, $value) = split(/\|\|/, $command, 2);
		if ($command eq 'quit') {
			$message = $value;
			last;
		}
	}

	$connection->quit($message);

	$connection->disconnect();

	$running = false;
	$connected = false;

	threads->exit();
}

#######
## FATAL ERROR
#######
## Display the given error message and shut down the bot.
#######
sub fatal_error($;@)
{
	my ($message, @parameters) = @_;

	Bot::error($message, @parameters);

	Bot::shutdown();
}

#######
## ERROR
#######
## Display the given error message (ERROR: is prepended)
#######
sub error($;@)
{
	my ($message, @parameters) = @_;

	Bot::log('ERROR: ' . $message, @parameters);
}

#######
## DEBUG LOGGING
#######
## Display the given message if debugging is enabled (DEBUG: is prepended)
#######
sub debug($;@)
{
	my ($message, @parameters) = @_;

	return unless $Bot::config->{'debug'};

	Bot::log('DEBUG: ' . $message, @parameters);
}

#######
## STATUS LOGGING
#######
sub status($;@)
{
	my ($message, @parameters) = @_;

	Bot::log($message, @parameters);
}

sub log($;@)
{
	my ($message, @parameters) = @_;

	chomp $message;

	my $outputMessage = '[' . localtime() . '] ' . sprintf($message, @parameters);

	unless ($no_console) {
		print $outputMessage, "\n";
	}

	if ($config->{'config_nick'}) {
		open(my $log, '>>', $config->{'config_nick'} . '.log');
		print $log $outputMessage, "\n";
		close($log);
	}
}

##############

#######
## MESSAGE TO CHANNEL OR THE BOT
## $to is undefined when message is private to bot
#######
sub message($$)
{
	my ($conn, $event) = @_;

	my $message = new Message($event);

	my $nick = $message->from();
	my $to   = $message->where();
	my $text = $message->raw();

	if (should_ignore($message)) {
		if ($message->is_public()) {
			status('IGNORED <%s/%s> %s', $nick, $to, $text);
		} else {
			status('IGNORED >%s< %s', $nick, $text);
		}
		return;
	}

	if ($message->is_public()) {
		status('<%s/%s> %s', $nick, $to, $text);
	} else {
		status('>%s< %s', $nick, $text);
	}
	Modules::dispatch($message);
}

#######
## ACTION
#######
sub handle_action($$)
{
	my ($conn, $event) = @_;

	my $from    = $event->{'nick'};
	my $to      = $event->{'to'}[0];
	my $message = $event->{'args'}[0];

	status('* %s/%s %s', $from, $to, $message);
}

###############

#######
## EVENT HANDLERS
#######
sub on_disconnect($$)
{
	my ($conn, $event) = @_;

	$connected = false;
}

sub on_nick_change($$)
{
	my ($conn, $event) = @_;

	my $old_nick = $event->{'nick'};
	my $new_nick = $event->{'args'}[0];

	status('%s is now known as %s', $old_nick, $new_nick);

	Modules::event('nickchange', {
		'from' => $old_nick,
		'to'   => $new_nick,
	});
}

sub nick_in_use($$)
{
	my ($conn, $event) = @_;

	status('Nickname is in use! Trying some alternatives.');

	$nick_retries++;

	if ($nick_retries == 1) {
		$config->{'nick'} = $config->{'config_nick'} . '_';
	} elsif ($nick_retries == 2) {
		$config->{'nick'} = $config->{'config_nick'};
	}
	change_nick($config->{'nick'});
}

sub on_quit($$)
{
	my ($conn, $event) = @_;

	my $who     = $event->{'nick'};
	my $message = $event->{'args'}[0];

	status('%s has quit IRC (%s)', $who, $message);
}

sub on_join($$)
{
	my ($conn, $event) = @_;

	my $channel = $event->{'to'}[0];
	my $nick    = $event->{'nick'};

	if ($config->{'nick'} eq $nick) {
		status('Joined channel %s', $channel);
		$channels{ $channel } = true;
	} else {
		status('%s has joined %s', $nick, $channel);

		Modules::event('join', {
			'channel' => $channel,
			'nick'    => $nick,
		});
	}
}

sub banned_from_channel($$)
{
	my ($conn, $event) = @_;

	my $channel = $event->{'args'}[1];

	status("Can't join %s - I've been banned!", $channel);
}

sub on_part($$)
{
	my ($conn, $event) = @_;

	my $channel = $event->{'to'}[0];
	my $user    = $event->{'nick'};
	my $message = $event->{'args'}[0];

	status('%s has left %s (%s)', $user, $channel, $message);

	Modules::event('part', {
		'channel' => $channel,
		'nick'    => $user,
	});
}

sub on_mode($$)
{
	my ($conn, $event) = @_;

	my $channel = $event->{'to'}[0];
	my $giver   = $event->{'nick'};

	# args has the mode changes in [0] and [n - 1] is an empty string
	my $num_changes = scalar($event->{'args'}) - 2;

	my @modes = split(//, $event->{'args'}[0]);

	my $modifier = shift @modes;

	for (my $i = 0; $i < scalar(@modes); $i++) {
		if ($modes[$i] eq '-' || $modes[$i] eq '+') {
			$modifier = $modes[$i];
			next;
		}

		if ($event->{'args'}[$i + 1]) {
			status('%s/%s sets mode %s%s %s', $giver, $channel, $modifier, $modes[ $i ], $event->{'args'}->[ $i + 1 ]);
		} else {
			status('%s/%s sets mode %s%s', $giver, $channel, $modifier, $modes[ $i ]);
		}
	}
}

sub on_topic($$)
{
	my ($conn, $event) = @_;

	if ($event->{'format'} eq 'server') {
		my $channel = $event->{'args'}[1];
		my $topic   = $event->{'args'}[2];
		status("Topic for %s is '%s'", $channel, $topic);
	} else {
		my $channel = $event->{'to'}[0];
		my $topic   = $event->{'args'}[0];
		my $who     = $event->{'nick'};

		status("%s has changed the topic for %s to '%s'", $who, $channel, $topic);
		Modules::event('topicchange', {
			'channel' => $channel,
			'nick'    => $who,
			'topic'   => $topic,
		});
	}
}

sub on_kick($$)
{
	my ($conn, $event) = @_;

	my $kicker  = $event->{'nick'};
	my $kicked  = $event->{'to'}[0];
	my $channel = $event->{'args'}[0];
	my $reason  = $event->{'args'}[1] || '';

	if ($kicked ne $config->{'nick'}) {
		status('%s has kicked %s from %s ($s)', $kicker, $kicked, $channel, $reason);
	} else {
		status('%s has kicked me from %s (%s)', $kicker, $channel, $reason);
		delete $channels{ $channel };
		join_chan($conn, $channel);
	}
}

sub on_invite($$)
{
	my ($conn, $event) = @_;

	my $inviter = $event->{'nick'};
	my $invitee = $event->{'to'}[0];
	my $channel = $event->{'args'}[0];

	if ($invitee ne $config->{'nick'}) {
		status('%s invited %s to %s', $inviter, $invitee, $channel);
	} else {
		status('%s invited me to %s', $inviter, $channel);
		my %allowed_channels = map { $_ => true } @{ $config->{'channels'}->{'allowed'} };
		if ($allowed_channels{ $channel }) {
			join_chan($conn, $channel);
		} else {
			status("%s isn't on the allowed channel list, not joining", $channel);
		}
	}
}

sub on_notice($$)
{
	my ($conn, $event) = @_;

	status('-%s- %s', $event->{'from'}, $event->{'args'}[0]);

	if ($event->{'nick'} eq 'NickServ' && $event->{'args'}[0] =~ /This nickname is registered and protected/i && $config->{'nickserv_pass'}) {
		Bot::say('NickServ', 'identify ' . $config->{'nickserv_pass'});
	}
}

sub on_server_notice($$)
{
	my ($conn, $event) = @_;

	status('-%s', $event->{'args'}[0]);
}

##############

#######
## SEND MESSAGE TO USER/CHANNEL
#######
sub say($$)
{
	my ($where, $message) = @_;

	return unless $message;

	local $Text::Wrap::columns = ($config->{'line_length'} || 350);
	my @lines = split(/\n/, Text::Wrap::wrap('', '', $message));

	foreach my $line (@lines) {
		next unless $line;
		status('</%s> %s', $where, $line);
		$connection->privmsg($where, $line);
	}
}

sub enqueue_say($$)
{
	my ($where, $message) = @_;

	return unless $message;

	# Add to stack
	push @commands, "say||$where||$message";
}

sub enqueue_action($$)
{
	my ($where, $message) = @_;

	return unless $message;

	# Add to stack
	push @commands, "action||$where||$message";
}

sub bot_command()
{
	my %funcs = (
		'part'    => \&part,
		'join'    => \&join,
		'say'     => \&say,
		'action'  => \&action,
		'discon'  => \&quit,
		'connect' => \&connect,
		'nick'    => \&change_nick,
		'reload'  => \&reload_modules,
		'load'    => \&load_module,
		'unload'  => \&unload_module,
		'debug'   => \&set_debug
	);

	while (my $command = shift @commands) {
		my ($func, @params) = split(/\|\|/, $command);

		if ($funcs{ $func }) {
			$funcs{ $func }->(@params);
		}
	}
}

##############
## IGNORE LIST
##############
sub load_ignore()
{
	open(my $ignore, '<', $config->{'ignore_list'}) or return;
	while (my $entry = <$ignore>) {
		chomp $entry;
		$ignores{ lc($entry) } = true;
	}
	close($ignore);
}

#######
## SHOULD MESSAGE BE IGNORED?
#######
## Parameters:
##   $message
##   - a Message object that should be tested
##
## Return value:
##   If the message should be ignored (because the sender's hostmask
##   matched an entry on the ignore list), returns true.
##   Otherwise, returns false.
#######
sub should_ignore($)
{
	my $message = shift;

	foreach my $ignore (keys %ignores) {
		# Escape everything, then unescape allowed wildcards
		my $ign = quotemeta($ignore);

		# Convert '*' in hostmask to '.*' in regexp
		$ign =~ s/\\\*/\.\*/g;
		# Convert '?' in hostmask to '.' in regexp
		$ign =~ s/\\\?/\./g;

		if ($message->fullhost() =~ /$ign/i) {
			return true;
		}
	}
	return false;
}

##############
## USEFUL IRC FUNCTIONS
## These are primarily for modules to use
##############
sub quit($)
{
	my $message = shift;

	$connection->quit($message);
#	$connection->shutdown();
}

sub join($)
{
	my $channel = shift;

	join_chan($connection, $channel);	
}

sub part($$)
{
	my ($channel, $reason) = @_;

	$reason = $reason || '';

	status('Leaving channel %s (%s)', $channel, $reason);

	$connection->part($channel, $reason);

	delete $channels{ $channel };
}

sub give_op($$)
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '+o', $user);
}

sub take_op($$)
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '-o', $user);
}

sub give_voice($$)
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '+v', $user);
}

sub take_voice($$)
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '-v', $user);
}

sub kick($$$)
{
	my ($channel, $user, $reason) = @_;

	$connection->kick($channel, $user, $reason);
}

sub action($$)
{
	my ($where, $what) = @_;

	status('* %s/%s %s', $config->{'nick'}, $where, $what);

	$connection->me($where, $what);
}

sub change_nick($)
{
	my $nick = shift;

	status("Changing nick to '%s'", $nick);

	$connection->nick($nick);

	my $oldnick = $config->{'nick'};

	$config->{'nick'} = $nick;

	Modules::event('mynickchange', { 'old' => $oldnick, 'new' => $nick });
}

sub save_ignore_list()
{
	open(my $newlist, '>', $config->{'ignore_list'} . '.tmp') or do { error("Updating ignore list failed: %s", $!); return; };
	foreach my $entry (keys %ignores) {
		print $newlist $entry . "\n";
	}
	close($newlist);
	File::Copy::move($config->{'ignore_list'} . '.tmp', $config->{'ignore_list'});
}

sub add_ignore($)
{
	my $entry = shift;

	status("Adding '%s' to the ignore list", $entry);

	$ignores{ lc($entry) } = true;

	save_ignore_list();
}

sub remove_ignore($)
{
	my $entry = shift;

	status("Removing '%s' from the ignore list", $entry);

	delete $ignores{ lc($entry) };

	save_ignore_list();
}

sub reload_modules(;$)
{
	my $module = shift;

	unless ($module) {
		status('Reloading modules');
		Modules::load_modules();
	} else {
		Modules::unload_module($module);
		Modules::load_module($module, false, false);
	}
}

sub load_module($)
{
	my $module = shift;

	Modules::load_module($module, false, false);
}

sub unload_module($)
{
	my $module = shift;

	Modules::unload_module($module);
}

sub set_debug($)
{
	my $debug = shift;

	return unless ($debug eq 'on' || $debug eq 'off');

	status('Setting debug status to %s', $debug);

	my $state = ($debug eq 'on');

	$config->{'debug'} = $state;
	$connection->debug($state);
}
