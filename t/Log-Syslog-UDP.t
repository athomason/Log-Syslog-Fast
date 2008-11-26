use strict;
use warnings;

use Test::More 'no_plan';
use IO::Socket::INET;

BEGIN { use_ok('Log::Syslog::UDP', ':all') };

my $test_port = 10514;
my $listener = IO::Socket::INET->new(
    Proto       => 'udp',
    LocalHost   => 'localhost',
    LocalPort   => $test_port,
    Reuse       => 1,
);
ok($listener, "listen on port $test_port");

my $logger = Log::Syslog::UDP->new("127.0.0.1", $test_port, 4, 6, "localhost", "test");
ok($logger, "->new returns something");

is(ref $logger, 'Log::Syslog::UDP', '->new returns a Log::Syslog::UDP object');

{
    eval {
        $logger->send("testing 1", time);
    };
    ok(!$@, "->send with time doesn't throw");

    # use select so test doesn't block on failure
    vec(my $rin = '', fileno($listener), 1) = 1;
    my $found = select(my $rout = $rin, undef, undef, 1);
    ok($found, "didn't time out while listening");

    if ($found) {
        $listener->recv(my $buf, 256);
        ok($buf =~ /^<38>/, "->send with time has the right priority");
        ok($buf =~ /testing 1$/, "->send with time sends right payload");
    }
}

{
    eval {
        $logger->send("testing 2");
    };
    ok(!$@, "->send without time doesn't throw");

    # use select so test doesn't block on failure
    vec(my $rin = '', fileno($listener), 1) = 1;
    my $found = select(my $rout = $rin, undef, undef, 1);
    ok($found, "didn't time out while listening");

    if ($found) {
        $listener->recv(my $buf, 256);
        ok($buf =~ /^<38>/, "->send without time has the right priority");
        ok($buf =~ /testing 2$/, "->send without time sends right payload");
    }
}

eval {
    $test_port++;
    $logger = Log::Syslog::UDP->new("127.0.0.1", $test_port, LOG_AUTH, LOG_INFO, "localhost", "test");

    eval {
        $logger->set_receiver("127.0.0.1", $test_port);
    };
    ok(!$@, "->set_receiver doesn't throw");

    eval {
        $logger->set_priority(LOG_NEWS, LOG_CRIT);
    };
    ok(!$@, "->set_priority doesn't throw");

    eval {
        $logger->set_sender("otherhost");
    };
    ok(!$@, "->set_sender doesn't throw");

    eval {
        $logger->set_name("test2");
    };
    ok(!$@, "->set_name doesn't throw");

    eval {
        $logger->set_pid("12345");
    };
    ok(!$@, "->set_name doesn't throw");

    $listener = IO::Socket::INET->new(
        Proto       => 'udp',
        LocalHost   => 'localhost',
        LocalPort   => $test_port,
        Reuse       => 1,
    );

    eval {
        $logger->send("testing 3");
    };
    ok(!$@, "->send after accessors doesn't throw");

    vec(my $rin = '', fileno($listener), 1) = 1;
    my $found = select(my $rout = $rin, undef, undef, 1);
    ok($found, "didn't time out while listening");

    if ($found) {
        $listener->recv(my $buf, 256);
        ok($buf, "send after setReceiver went to correct port");
        ok($buf =~ /^<58>/, "->send after setPriority has the right priority");
        ok($buf =~ /otherhost/, "->send after setSender has the right sender");
        ok($buf =~ /test2\[/, "->send after setName has the right name");
        ok($buf =~ /\[12345\]/, "->send after setName has the right pid");
        ok($buf =~ /testing 3$/, "->send after accessors sends right payload");
    }
};

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
