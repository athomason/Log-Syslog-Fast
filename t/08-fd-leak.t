# test for fix of https://rt.cpan.org/Ticket/Display.html?id=73569

use strict;
use warnings;

use Test::More tests => 2;
use File::Temp 'tempdir';
use IO::Select;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Log::Syslog::Constants ':all';
use POSIX 'strftime';

require 't/lib/LSFServer.pm';

use Log::Syslog::Fast ':protos';

my $test_dir = tempdir(CLEANUP => 1);

# old IO::Socket::INET fails with "Bad service '0'" when attempting to use
# wildcard port
my $port = 24767;
sub listen_port {
    return 0 if $IO::Socket::INET::VERSION >= 1.31;
    diag("Using port $port for IO::Socket::INET v$IO::Socket::INET::VERSION");
    return $port++;
}

my $listener = IO::Socket::INET->new(
    Proto       => 'tcp',
    Type        => SOCK_STREAM,
    LocalHost   => 'localhost',
    LocalPort   => listen_port(),
    Listen      => 5,
    Reuse       => 1,
) or die $!;

my $server = StreamServer->new(
    listener    => $listener,
    proto       => LOG_TCP,
    address     => [$listener->sockhost, $listener->sockport],
);

ok($server->{listener}, "listen") or diag("listen failed: $!");

my $logger = $server->connect('Log::Syslog::Fast' => LOG_AUTH, LOG_INFO, 'localhost', 'test');

my $initial_sock = $logger->_get_sock;

for (1 .. 100) {
    $logger->set_receiver($server->proto, $server->address);
    $server->accept();
}

is($logger->_get_sock, $initial_sock, "sock fd is recycled across reconnections")
    or diag sprintf "sock went from %d to %d\n", $initial_sock, $logger->_get_sock;

# vim: filetype=perl
