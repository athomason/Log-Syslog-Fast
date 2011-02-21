use strict;
use warnings;

use Test::More tests => 1;

use IO::Socket::INET;
use Log::Syslog::Fast ':all';

my $port = 11514;

eval {
    Log::Syslog::Fast->new(LOG_UNIX, 'a' x 10000, 0, LOG_LOCAL0, LOG_INFO, "mymachine", "logger");
};
like($@, qr/^Error in ->new/, "long filename");

my $bufsize = 16384;

# attempt buffer overruns

# hostname
for my $size (-30 .. 30) {
    #note "hostname offset $size\n";
    my $hostname = '1' x ($bufsize + $size);
    eval {
        Log::Syslog::Fast->new(LOG_UNIX, $hostname, 0, LOG_LOCAL0, LOG_INFO, "mymachine", "logger")->send('');
    };
}

# sender
for my $size (-30 .. 30) {
    #note "sender offset $size\n";
    my $sender = 'x' x ($bufsize + $size);
    my $l = listener();
    my $logger = Log::Syslog::Fast->new(LOG_TCP, '127.0.0.1', $port, LOG_LOCAL0, LOG_INFO, $sender, "logger");
    $l->accept;
    eval { $logger->send("\n"); }
}

# program name
for my $size (-30 .. 30) {
    #note "name offset $size\n";
    my $name = 'x' x ($bufsize + $size);
    my $l = listener();
    my $logger = Log::Syslog::Fast->new(LOG_TCP, '127.0.0.1', $port, LOG_LOCAL0, LOG_INFO, "mymachine", $name);
    $l->accept;
    eval { $logger->send("\n"); }
}

# message
for my $size (-30 .. 30) {
    #note "message offset $size\n";
    my $msg = 'x' x ($bufsize + $size);
    my $l = listener();
    my $logger = Log::Syslog::Fast->new(LOG_TCP, '127.0.0.1', $port, LOG_LOCAL0, LOG_INFO, "mymachine", "logger");
    $l->accept;
    eval { $logger->send("$msg\n"); }
}

sub listener {
    my $listener = IO::Socket::INET->new(
        Proto       => 'tcp',
        Type        => SOCK_STREAM,
        LocalHost   => '127.0.0.1',
        LocalPort   => $port,
        Reuse       => 1,
        Listen      => 1,
    ) or die $!;
    return $listener;
}

# vim: filetype=perl
