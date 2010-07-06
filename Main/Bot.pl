#!/usr/bin/perl -w

use strict;
use threads;
use threads::shared;

use File::Copy;
use Getopt::Long;
use Net::IRC;
use POSIX;

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
my  %ignores;
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
$config = &load_config();

# Perform pre-loading initialization for module stuff
&Modules::init();

# Unbuffer standard output
select(STDOUT);
$| = 1;

# Intercept Ctrl+C
$SIG{'INT'} = \&shutdown;

# Load ignore list
&load_ignore();

# Load extras
&Modules::load_modules();

#######
## START IRCING
#######

our $bot     = threads->create('bot');
our $console = threads->create('Console::console');

$bot->join();
$console->join();


sub bot()
{
	$SIG{'USR1'} = \&bot_command;
	$SIG{'TERM'} = \&bot_shutdown;
	$SIG{'INT'}  = sub { &bot_shutdown(); $console->kill('SIGINT'); threads->exit(); };

	while (1) {
		# Reset list of joined channels
		%channels = ();

		# Connect to the server
		&connect();

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

		while ($connection->connected()) {
			$irc->do_one_loop();
			if (scalar(@commands) > 0) {
				&bot_command();
			}
		}
	}
}

#######
## LOAD CONFIG
#######
sub load_config()
{
	open(CONFIG, $config_file || "config") or die "Can't open config file! -- $!";
	my %config_values;

	while (my $line = <CONFIG>) {
		next if ($line =~ /^\#/);
		my ($param, $value) = split(/\s+/, $line, 2);
		chomp $value;
		$config_values{ $param } = $value;
	}
	close(CONFIG);

	# 'config_nick' represents the nickname as entered in the config file, while 'nick' represents the actual name in use
	$config_values{'config_nick'} = $config_values{'nick'} unless $config_values{'config_nick'};

	return \%config_values;
}

#######
## ERROR HANDLER
#######
sub on_error()
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
	&status("Connecting to port $config->{'server_port'} of server $config->{'server_name'}...");

	$irc = new Net::IRC;
	$irc->debug($config->{'debug'} ? true : false);
	$irc->timeout(5);
	$connection = $irc->newconn(
		Nick     => $config->{'nick'},
		Server   => $config->{'server_name'},
		Port     => $config->{'server_port'},
		Ircname  => $config->{'name'} || $config->{'nick'},
		Username => $config->{'username'} || $config->{'nick'}
	);

	if (!$connection) {
		&status("Unable to connect to server.");
		&shutdown();
	}
}

#######
## JOIN CHANNEL
#######
sub join_chan()
{
	my ($conn, $chan) = @_;

	if (exists $channels{ $chan }) {
		&status("Already in $chan");
		return;
	}

	&status("Joining $chan");

	$conn->join($chan);
}

#######
## ON CONNECT
#######
sub on_connect()
{
	my ($conn, $event) = @_;

	&status("Joining channels");

	my @channels = split(/\s+/, $config->{'channels'});

	foreach my $chan (@channels) {
		&join_chan($conn, $chan);
	}
}

#######
## SHUTDOWN
#######
sub shutdown()
{
	&status("Shutting down...");

	$bot->kill('SIGTERM');
	$console->kill('SIGTERM');

	# End threads
	threads->exit();
}

sub bot_shutdown()
{
	&status("Bot thread is shutting down...");

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
## ERROR
#######
sub error()
{
	my $message = shift;

	print STDERR "ERROR: $message\n";

	&shutdown();
}

#######
## STATUS LOGGING
#######
sub status()
{
	my $message = shift;

	# Strip trailing \n, if any
	$message =~ s/\n$//;

	unless ($no_console) {
		print '[' . localtime() . '] ' . $message . "\n";
	}

	open(LOG, '>>' . $config->{'config_nick'} . '.log');
	print LOG '[' . localtime() . '] ' . $message . "\n";
	close(LOG);
}

##############

#######
## MESSAGE TO CHANNEL OR THE BOT
## $to is undefined when message is private to bot
#######
sub message()
{
	my ($conn, $event) = @_;

	my $message = new Message($event);

	my $nick = $message->from();
	my $to   = $message->where();
	my $text = $message->raw();

	if (&should_ignore($message)) {
		if ($message->is_public()) {
			&status("IGNORED <$nick/$to> $text");
		} else {
			&status("IGNORED >$nick< $text");
		}
		return;
	}

	if ($message->is_public()) {
		&status("<$nick/$to> $text");
	} else {
		&status(">$nick< $text");
	}
	&Modules::dispatch($message);
}

#######
## ACTION
#######
sub handle_action()
{
	my ($conn, $event) = @_;

	my $from    = $event->{'nick'};
	my $to      = $event->{'to'}[0];
	my $message = $event->{'args'}[0];

	&status("* $from/$to $message");
}

###############

#######
## EVENT HANDLERS
#######
sub on_disconnect()
{
	my ($conn, $event) = @_;

	$connected = false;
}

sub on_nick_change()
{
	my ($conn, $event) = @_;

	my $old_nick = $event->{'nick'};
	my $new_nick = $event->{'args'}[0];

	&status("$old_nick is now known as $new_nick");
}

sub nick_in_use()
{
	my ($conn, $event) = @_;

	&status("Nickname is in use! Trying some alternatives.");

	$nick_retries++;

	if ($nick_retries == 1) {
		$config->{'nick'} = $config->{'config_nick'} . '_';
	} elsif ($nick_retries == 2) {
		$config->{'nick'} = $config->{'config_nick'};
	}
	&change_nick($config->{'nick'});
}

sub on_quit()
{
	my ($conn, $event) = @_;

	my $who     = $event->{'nick'};
	my $message = $event->{'args'}[0];

	&status("$who has quit IRC ($message)");
}

sub on_join()
{
	my ($conn, $event) = @_;

	my $channel = $event->{'to'}[0];
	my $nick    = $event->{'nick'};

	if ($config->{'nick'} eq $nick) {
		&status("Joined channel $channel");
		$channels{ $channel } = true;
	} else {
		&status("$nick has joined $channel");
	}
}

sub banned_from_channel()
{
	my ($conn, $event) = @_;

	my $channel = $event->{'args'}[1];

	&status("Can't join $channel - I've been banned!");
}

sub on_part()
{
	my ($conn, $event) = @_;

	my $channel = $event->{'to'}[0];
	my $user    = $event->{'nick'};
	my $message = $event->{'args'}[0];

	&status("$user has left $channel ($message)");
}

sub on_mode()
{
	my ($conn, $event) = @_;

	my $chan  = $event->{'to'}[0];
	my $giver = $event->{'nick'};

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
			&status("$giver/$chan sets mode ${modifier}$modes[$i] " . $event->{'args'}[$i + 1]);
		} else {
			&status("$giver/$chan sets mode ${modifier}$modes[$i]");
		}
	}
}

sub on_topic()
{
	my ($conn, $event) = @_;

	if ($event->{'format'} eq 'server') {
		my $channel = $event->{'args'}[1];
		my $topic   = $event->{'args'}[2];
		&status("Topic for $channel is '$topic'");
	} else {
		my $channel = $event->{'to'}[0];
		my $topic   = $event->{'args'}[0];
		my $who     = $event->{'nick'};

		&status("$who has changed the topic for $channel to '$topic'");
	}
}

sub on_kick()
{
	my ($conn, $event) = @_;

	my $kicker  = $event->{'nick'};
	my $kicked  = $event->{'to'}[0];
	my $channel = $event->{'args'}[0];
	my $reason  = $event->{'args'}[1] || '';

	if ($kicked ne $config->{'nick'}) {
		&status("$kicker has kicked $kicked from $channel ($reason)");
	} else {
		&status("$kicker has kicked me from $channel! ($reason)");
		delete $channels{ $channel };
		&join_chan($conn, $channel);
	}
}

sub on_invite()
{
	my ($conn, $event) = @_;

	my $inviter = $event->{'nick'};
	my $invitee = $event->{'to'}[0];
	my $channel = $event->{'args'}[0];

	if ($invitee ne $config->{'nick'}) {
		&status("$inviter invited invitee to $channel");
	} else {
		&status("$inviter invited me to $channel");
		my %allowed_channels = map { $_ => true } split(/\s+/, $config->{'allowed_channels'});
		if ($allowed_channels{ $channel }) {
			&join_chan($conn, $channel);
		} else {
			&status("$channel isn't on the allowed channel list.");
		}
	}
}

sub on_notice()
{
	my ($conn, $event) = @_;

	&status('-' . $event->{'from'} . '- ' . $event->{'args'}[0]);

	if ($event->{'nick'} eq 'NickServ' && $event->{'args'}[0] =~ /This nickname is registered and protected/i && $config->{'nickserv_pass'}) {
		&say('NickServ', 'identify ' . $config->{'nickserv_pass'});
	}
}

sub on_server_notice()
{
	my ($conn, $event) = @_;

	&status('-' . $event->{'args'}[0]);
}

##############

#######
## SEND MESSAGE TO USER/CHANNEL
#######
sub say()
{
	my ($where, $message) = @_;

	return unless $message;

	foreach my $line (split(/\r*\n/, $message)) {
		next unless $line;
		&status("</$where> $line");
		$connection->privmsg($where, $line);
	}
}

sub enqueue_say()
{
	my ($where, $message, $bot) = @_;

	return unless $message;

	# Add to stack
	push @commands, "say||$where||$message";
}

sub enqueue_action()
{
	my ($where, $message, $bot) = @_;

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
	open(IGNORE, $config->{'ignore_list'}) || return;
	while (my $ignore = <IGNORE>) {
		chomp $ignore;
		$ignores{ lc($ignore) } = true;
	}
	close(IGNORE);
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
sub quit()
{
	my $message = shift;

	$connection->quit($message);
#	$connection->shutdown();
}

sub join()
{
	my $channel = shift;

	&join_chan($connection, $channel);	
}

sub part()
{
	my ($channel, $reason) = @_;

	$reason = $reason || '';

	&status("Leaving channel $channel ($reason)");

	$connection->part($channel, $reason);

	delete $channels{ $channel };
}

sub give_op()
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '+o', $user);
}

sub take_op()
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '-o', $user);
}

sub give_voice()
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '+v', $user);
}

sub take_voice()
{
	my ($channel, $user) = @_;

	$connection->mode($channel, '-v', $user);
}

sub kick()
{
	my ($channel, $user, $reason) = @_;

	$connection->kick($channel, $user, $reason);
}

sub action()
{
	my ($where, $what) = @_;

	&status("* $config->{'nick'}/$where $what");

	$connection->me($where, $what);
}

sub change_nick()
{
	my $nick = shift;

	&status("Changing nick to '$nick'");

	$connection->nick($nick);

	$config->{'nick'} = $nick;
}

sub add_ignore()
{
	my $ignore = shift;

	&status("Adding '$ignore' to the ignore list");

	open(IGNORE, '>>' . $config->{'ignore_list'});
	print IGNORE $ignore . "\n";
	close(IGNORE);

	$ignores{ lc($ignore) } = true;
}

sub remove_ignore()
{
	my $ignore = shift;

	&status("Removing '$ignore' from the ignore list");

	open(IGNORE, $config->{'ignore_list'});
	open(NEWLIST, '>' . $config->{'ignore_list'} . '.tmp');
	while (my $ign = <IGNORE>) {
		if (lc($ignore) ne lc($ign)) {
			print NEWLIST $ign . "\n";
		}
	}
	close(NEWLIST);
	close(IGNORE);
	&File::Copy::move($config->{'ignore_list'} . '.tmp', $config->{'ignore_list'});

	delete $ignores{ lc($ignore) };
}

sub reload_modules()
{
	my $module = shift;

	unless ($module) {
		&status("Reloading modules");
		&Modules::load_modules();
	} else {
		&Modules::unload_module($module);
		&Modules::load_module($module, false, false);
	}
}

sub load_module()
{
	my $module = shift;

	&Modules::load_module($module, false, false);
}

sub unload_module()
{
	my $module = shift;

	&Modules::unload_module($module);
}

sub set_debug()
{
	my $debug = shift;

	return unless ($debug eq 'on' || $debug eq 'off');

	&status("Setting debug status to $debug");

	my $state = ($debug eq 'on');

	$config->{'debug'} = $state;
	$connection->debug($state);
}
