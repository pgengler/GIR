use strict;
use warnings;
use feature ':5.10';

use File::Spec;
use IO::Socket::UNIX;

my $temp_directory = File::Spec->tmpdir();
my $socket_path = File::Spec->catfile($temp_directory, 'ircbot');

if (scalar(@ARGV) == 0) {
  print STDERR "Usage: perl $0 <command>\n";
  exit(1);
}

unless (-S $socket_path) {
  say STDERR "Server socket (${socket_path}) not found; is the bot running?";
  exit(1);
}

my $socket = new IO::Socket::UNIX(
  'Peer' => $socket_path,
  'Type' => SOCK_STREAM,
);

unless ($socket) {
  say STDERR "Unable to connect to socket: $!\nIs the bot running?";
  exit(1);
}

print $socket join(' ', @ARGV);
