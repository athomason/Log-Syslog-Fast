use strict;
use warnings;

use Test::More tests => 3 * 31 + 1;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Log::Syslog::Constants ':all';
use POSIX 'strftime';

BEGIN { use_ok('Log::Syslog::Fast', ':protos') };

my $p;

my $test_port = 10514;
my $test_file = '/tmp/devlog-lsf';

END { unlink $test_file }

for my $proto (LOG_UDP, LOG_TCP, LOG_UNIX) {

    $p = ($proto == LOG_UDP ? 'udp' : $proto == LOG_TCP ? 'tcp' : 'unix');

    my ($listener, $test_host) = listener();
    ok($listener, "$p: listen on " . ($proto == LOG_UNIX ? $test_host : " port $test_port")) or
        diag("listen failed: $!");

    my @params = (LOG_AUTH, LOG_INFO, "localhost", "test");
    my $logger = Log::Syslog::Fast->new($proto, $test_host, $test_port, @params);
    ok($logger, "$p: ->new returns something");

    eval { Log::Syslog::Fast->new($proto, '%^!/0', 0, @params) };
    like($@, qr/^Error in ->new/, "$p: bad ->new call throws an exception");

    is(ref $logger, 'Log::Syslog::Fast', "$p: ->new returns a Log::Syslog::Fast object");

    my $receiver = l2r($listener);

    my ($msg, $expected);

    {
        $msg = 'testing 1';
        $expected = expected_payload(@params, $$, $msg);

        my $sent = eval { $logger->send($msg, time) };
        ok(!$@, "$p: ->send with time doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while waiting for data");

        if ($found) {
            $receiver->recv(my $buf, 256);

            ok($buf =~ /^<38>/, "$p: ->send with time has the right priority");
            ok($buf =~ /$msg$/, "$p: ->send with time has the right message");
            is($buf, $expected, "$p: ->send with time has correct payload");
        }
    }

    {
        $msg = 'testing 2';
        $expected = expected_payload(@params, $$, $msg);

        my $sent = eval { $logger->send($msg) };
        ok(!$@, "$p: ->send without time doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while waiting for data");

        if ($found) {
            $receiver->recv(my $buf, 256);
            ok($buf =~ /^<38>/, "$p: ->send without time has the right priority");
            ok($buf =~ /$msg$/, "$p: ->send without time sends right payload");
            is($buf, $expected, "$p: ->send without time has correct payload");
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
        $logger = Log::Syslog::Fast->new($proto, $test_host, $test_port, @params);

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
            $logger->set_sender('otherhost');
        };
        ok(!$@, "$p: ->set_sender doesn't throw");

        eval {
            $logger->set_name('test2');
        };
        ok(!$@, "$p: ->set_name doesn't throw");

        eval {
            $logger->set_pid(12345);
        };
        ok(!$@, "$p: ->set_pid doesn't throw");

        my $receiver = l2r($listener);

        $msg = "testing 3";
        $expected = expected_payload(LOG_NEWS, LOG_CRIT, 'otherhost', 'test2', 12345, $msg);

        my $sent = eval { $logger->send($msg) };
        ok(!$@, "$p: ->send after accessors doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while listening");

        if ($found) {
            $receiver->recv(my $buf, 256);
            ok($buf, "$p: send after setReceiver went to correct port");
            ok($buf =~ /^<58>/, "$p: ->send after setPriority has the right priority");
            ok($buf =~ /otherhost/, "$p: ->send after setSender has the right sender");
            ok($buf =~ /test2\[/, "$p: ->send after setName has the right name");
            ok($buf =~ /\[12345\]/, "$p: ->send after setName has the right pid");
            ok($buf =~ /$msg$/, "$p: ->send after accessors sends right message");
            is($buf, $expected, "$p: ->send after accessors has right payload");
        }
    };
    diag($@) if $@;
}

sub expected_payload {
    my ($facility, $severity, $sender, $name, $pid, $msg) = @_;
    return sprintf "<%d>%s %s %s[%d]: %s",
        ($facility << 3) | $severity,
        strftime("%h %e %T", localtime(time)),
        $sender, $name, $pid, $msg;
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
