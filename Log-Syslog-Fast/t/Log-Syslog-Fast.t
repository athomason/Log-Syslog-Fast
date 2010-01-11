use strict;
use warnings;

use Test::More 'no_plan';
use IO::Socket::INET;
use IO::Socket::UNIX;
use Log::Syslog::Constants ':all';

BEGIN { use_ok('Log::Syslog::Fast', ':protos') };

my $p;

my $test_port = 10514;
my $test_file = '/tmp/devlog-lsf';

END { unlink $test_file }

my $payload_len = 47 + length "$$";

for my $proto (LOG_UDP, LOG_TCP, LOG_UNIX) {

    $p = ($proto == LOG_UDP ? 'udp' : $proto == LOG_TCP ? 'tcp' : 'unix');

    my ($listener, $test_host) = listener();
    ok($listener, "$p: listen on " . ($proto == LOG_UNIX ? $test_host : " port $test_port"));

    my $logger = Log::Syslog::Fast->new($proto, $test_host, $test_port, 4, 6, "localhost", "test");
    ok($logger, "$p: ->new returns something");

    is(ref $logger, 'Log::Syslog::Fast', "$p: ->new returns a Log::Syslog::Fast object");

    my $receiver = l2r($listener);

    {
        my $sent = eval { $logger->send("testing 1", time) };
        ok(!$@, "$p: ->send with time doesn't throw");
        is($sent, $payload_len, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while waiting for data");

        if ($found) {
            $receiver->recv(my $buf, 256);
            is(length $buf, $payload_len, "$p: payload is right size");
            ok($buf =~ /^<38>/, "$p: ->send with time has the right priority");
            ok($buf =~ /testing 1$/, "$p: ->send with time sends right payload");
        }
    }

    {
        my $sent = eval { $logger->send("testing 2") };
        ok(!$@, "$p: ->send without time doesn't throw");
        is($sent, $payload_len, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while waiting for data");

        if ($found) {
            $receiver->recv(my $buf, 256);
            is(length $buf, $payload_len, "$p: payload is right size");
            ok($buf =~ /^<38>/, "$p: ->send without time has the right priority");
            ok($buf =~ /testing 2$/, "$p: ->send without time sends right payload");
        }
    }

    eval {
        $test_port++;
        if ($p eq 'unix') {
            undef $logger;
            undef $listener;
            unlink $test_file;
        }
        ($listener, $test_host) = listener();
        $logger = Log::Syslog::Fast->new($proto, $test_host, $test_port, LOG_AUTH, LOG_INFO, "localhost", "test");

        $listener->accept if $p eq 'tcp' or $p eq 'unix'; # ignore first connection

        eval {
            $logger->set_receiver($proto, $test_host, $test_port);
        };
        ok(!$@, "$p: ->set_receiver doesn't throw");

        eval {
            $logger->set_priority(LOG_NEWS, LOG_CRIT);
        };
        ok(!$@, "$p: ->set_priority doesn't throw");

        eval {
            $logger->set_sender("otherhost");
        };
        ok(!$@, "$p: ->set_sender doesn't throw");

        eval {
            $logger->set_name("test2");
        };
        ok(!$@, "$p: ->set_name doesn't throw");

        eval {
            $logger->set_pid("12345");
        };
        ok(!$@, "$p: ->set_name doesn't throw");

        my $receiver = l2r($listener);

        my $sent = eval { $logger->send("testing 3") };
        ok(!$@, "$p: ->send after accessors doesn't throw");
        is($sent, 53, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while listening");

        if ($found) {
            $receiver->recv(my $buf, 256);
            ok($buf, "$p: send after setReceiver went to correct port");
            is(length $buf, 53, "$p: payload is right size");
            ok($buf =~ /^<58>/, "$p: ->send after setPriority has the right priority");
            ok($buf =~ /otherhost/, "$p: ->send after setSender has the right sender");
            ok($buf =~ /test2\[/, "$p: ->send after setName has the right name");
            ok($buf =~ /\[12345\]/, "$p: ->send after setName has the right pid");
            ok($buf =~ /testing 3$/, "$p: ->send after accessors sends right payload");
        }
    };
    diag($@) if $@;
}

sub listener {
    if ($p eq 'unix') {
        return (IO::Socket::UNIX->new(
            Local   => $test_file,
            Listen  => 1,
        ), $test_file);
    }
    else {
        return (IO::Socket::INET->new(
            Proto       => $p,
            LocalHost   => 'localhost',
            LocalPort   => $test_port,
            ($p eq 'tcp' ? (Listen => 5) : ()),
            Reuse       => 1,
        ), 'localhost');
    }
}

sub l2r {
    my $listener = shift;
    return $listener if $p eq 'udp';
    if ($p eq 'tcp' or $p eq 'unix') {
        my $receiver = $listener->accept;
        $receiver->blocking(0);
        return $receiver;
    }
}

# use select so test won't block on failure
sub wait_for_readable {
    my $sock = shift;
    vec(my $rin = '', fileno($sock), 1) = 1;
    return select(my $rout = $rin, undef, undef, 1);
}

# vim: filetype=perl
