use strict;
use warnings;

use Test::More tests => 10;
use IO::Select;
use IO::Socket::INET;
use Log::Syslog::Constants ':all';
use POSIX 'strftime';

require 't/lib/LSFServer.pm';

use Log::Syslog::Fast ':protos';

# old IO::Socket::INET fails with "Bad service '0'" when attempting to use
# wildcard port
my $port = 24767;
sub listen_port {
    return 0 if $IO::Socket::INET::VERSION >= 1.31;
    diag("Using port $port for IO::Socket::INET v$IO::Socket::INET::VERSION");
    return $port++;
}

my %servers = (
    udp => sub {
        my $listener = IO::Socket::INET->new(
            Proto       => 'udp',
            Type        => SOCK_DGRAM,
            LocalHost   => 'localhost',
            LocalPort   => listen_port(),
            Reuse       => 1,
        ) or die $!;
        return DgramServer->new(
            listener    => $listener,
            proto       => LOG_UDP,
            address     => [$listener->sockhost, $listener->sockport],
        );
    },
);

# strerror(3) messages on linux in the "C" locale are included below for reference

my @params = (LOG_AUTH, LOG_INFO, 'localhost', 'test');

for my $p (sort keys %servers) {
    my $listen = $servers{$p};

    # basic behavior
    eval {
        my $server = $listen->();
        ok($server->{listener}, "$p: listen") or diag("listen failed: $!");

        my $logger = $server->connect('Log::Syslog::Fast' => @params);
        ok($logger, "$p: ->new returns something");
        is(ref $logger, 'Log::Syslog::Fast', "$p: ->new returns a Log::Syslog::Fast object");

        my $receiver = $server->accept;
        ok($receiver, "$p: accepted");

        my $time = time;

        my $msg = '.' x 4500; # larger than INITIAL_BUFSIZE

        my @payload_params = (@params, $$, $msg, $time);
        my $expected = expected_payload(@payload_params);

        my $sent = eval { $logger->send($msg) };
        ok(!$@, "$p: ->send doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while waiting for data");

        if ($found) {
            $receiver->recv(my $buf, 5000);

            ok($buf =~ /^<38>/, "$p: ->send has the right priority");
            ok($buf =~ /$msg$/, "$p: ->send has the right message");
            ok(payload_ok($buf, @payload_params), "$p: ->send has correct payload");
        }
    };
    diag($@) if $@;
}

sub expected_payload {
    my ($facility, $severity, $sender, $name, $pid, $msg, $time) = @_;
    return sprintf "<%d>%s %s %s[%d]: %s",
        ($facility << 3) | $severity,
        strftime("%h %e %T", localtime($time)),
        $sender, $name, $pid, $msg;
}

sub payload_ok {
    my ($payload, @payload_params) = @_;
    for my $offset (0, -1, 1) {
        my $allowed = expected_payload(@payload_params);
        return 1 if $allowed eq $payload;
    }
    return 0;
}

sub allowed_payloads {
    my @params = @_;
    my $time = pop @params;
    return map { expected_payload(@params, $time + $_) } (-1, 0, 1);
}

# use select so test won't block on failure
sub wait_for_readable {
    my $sock = shift;
    return IO::Select->new($sock)->can_read(1);
}
