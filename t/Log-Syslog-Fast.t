use strict;
use warnings;

use Test::More 'no_plan';
use IO::Socket::INET;

BEGIN { use_ok('Log::Syslog::Fast', ':all') };

is(LOG_EMERG,    0,  'LOG_EMERG');
is(LOG_ALERT,    1,  'LOG_ALERT');
is(LOG_CRIT,     2,  'LOG_CRIT');
is(LOG_ERR,      3,  'LOG_ERR');
is(LOG_WARNING,  4,  'LOG_WARNING');
is(LOG_NOTICE,   5,  'LOG_NOTICE');
is(LOG_INFO,     6,  'LOG_INFO');
is(LOG_DEBUG,    7,  'LOG_DEBUG');

is(LOG_KERN,     0,  'LOG_KERN');
is(LOG_USER,     1,  'LOG_USER');
is(LOG_MAIL,     2,  'LOG_MAIL');
is(LOG_DAEMON,   3,  'LOG_DAEMON');
is(LOG_AUTH,     4,  'LOG_AUTH');
is(LOG_SYSLOG,   5,  'LOG_SYSLOG');
is(LOG_LPR,      6,  'LOG_LPR');
is(LOG_NEWS,     7,  'LOG_NEWS');
is(LOG_UUCP,     8,  'LOG_UUCP');
is(LOG_CRON,     9,  'LOG_CRON');
is(LOG_AUTHPRIV, 10, 'LOG_AUTHPRIV');
is(LOG_FTP,      11, 'LOG_FTP');
is(LOG_LOCAL0,   16, 'LOG_LOCAL0');
is(LOG_LOCAL1,   17, 'LOG_LOCAL1');
is(LOG_LOCAL2,   18, 'LOG_LOCAL2');
is(LOG_LOCAL3,   19, 'LOG_LOCAL3');
is(LOG_LOCAL4,   20, 'LOG_LOCAL4');
is(LOG_LOCAL5,   21, 'LOG_LOCAL5');
is(LOG_LOCAL6,   22, 'LOG_LOCAL6');
is(LOG_LOCAL7,   23, 'LOG_LOCAL7');

my $p;

my $test_port = 10514;

my $payload_len = 47 + length "$$";

for my $proto (LOG_UDP, LOG_TCP) {

    $p = ($proto == LOG_UDP ? 'udp' : 'tcp');

    my $listener = listener();
    ok($listener, "$p: listen on port $test_port");

    my $logger = Log::Syslog::Fast->new($proto, "127.0.0.1", $test_port, 4, 6, "localhost", "test");
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
        $listener = listener();
        $logger = Log::Syslog::Fast->new($proto, "127.0.0.1", $test_port, LOG_AUTH, LOG_INFO, "localhost", "test");

        $listener->accept if $p eq 'tcp'; # ignore first connection

        eval {
            $logger->set_receiver($proto, "127.0.0.1", $test_port);
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
}

sub listener {
    return IO::Socket::INET->new(
        Proto       => $p,
        LocalHost   => 'localhost',
        LocalPort   => $test_port,
        ($p eq 'tcp' ? (Listen => 5) : ()),
        Reuse       => 1,
    );
}

sub l2r {
    my $listener = shift;
    return $listener if $p eq 'udp';
    if ($p eq 'tcp') {
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
