use strict;
use warnings;

use Test::More tests => 148;
use File::Temp 'tempdir';
use IO::Select;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Log::Syslog::Constants ':all';
use POSIX 'strftime';

require 't/lib/LSFServer.pm';

use Log::Syslog::Fast::PP qw(:protos :formats);

my $test_dir = tempdir(CLEANUP => 1);

# old IO::Socket::INET fails with "Bad service '0'" when attempting to use
# wildcard port
my $port = 24767;
sub listen_port {
    return 0 if $IO::Socket::INET::VERSION >= 1.31;
    diag("Using port $port for IO::Socket::INET v$IO::Socket::INET::VERSION");
    return $port++;
}

my %servers = (
    tcp => sub {
        my $listener = IO::Socket::INET->new(
            Proto       => 'tcp',
            Type        => SOCK_STREAM,
            LocalHost   => 'localhost',
            LocalPort   => listen_port(),
            Listen      => 5,
            Reuse       => 1,
        ) or die $!;
        return StreamServer->new(
            listener    => $listener,
            proto       => LOG_TCP,
            address     => [$listener->sockhost, $listener->sockport],
        );
    },
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
    unix_stream => sub {
        my $listener = IO::Socket::UNIX->new(
            Local   => "$test_dir/stream",
            Type    => SOCK_STREAM,
            Listen  => 1,
        ) or die $!;
        return StreamServer->new(
            listener    => $listener,
            proto       => LOG_UNIX,
            address     => [$listener->hostpath, 0],
        );
    },
    unix_dgram => sub {
        my $listener = IO::Socket::UNIX->new(
            Local   => "$test_dir/dgram",
            Type    => SOCK_DGRAM,
            Listen  => 1,
        ) or die $!;
        return DgramServer->new(
            listener    => $listener,
            proto       => LOG_UNIX,
            address     => [$listener->hostpath, 0],
        );
    },
);

# strerror(3) messages on linux in the "C" locale are included below for reference

my @params = (LOG_AUTH, LOG_INFO, 'localhost', 'test');

for my $proto (LOG_TCP, LOG_UDP, LOG_UNIX) {
    eval { Log::Syslog::Fast::PP->new($proto, '%^!/0', 0, @params) };
    like($@, qr/^Error in/, "$proto: bad ->new call throws an exception");
}

for my $p (sort keys %servers) {
    my $listen = $servers{$p};

    # basic behavior
    eval {
        my $server = $listen->();
        ok($server->{listener}, "$p: listen") or diag("listen failed: $!");

        my $logger = $server->connect('Log::Syslog::Fast::PP' => @params);
        ok($logger, "$p: ->new returns something");
        is(ref $logger, 'Log::Syslog::Fast::PP', "$p: ->new returns a Log::Syslog::Fast::PP object");

        my $receiver = $server->accept;
        ok($receiver, "$p: accepted");

        my $time = time;
        for my $config (['without time'], ['with time', $time]) {
            my ($msg, @extra) = @$config;

            my @payload_params = (@params, $$, $msg, $time);
            my $expected = expected_payload(@payload_params, LOG_RFC3164);

            my $sent = eval { $logger->send($msg, @extra) };
            ok(!$@, "$p: ->send $msg doesn't throw");
            is($sent, length $expected, "$p: ->send $msg sent whole payload");

            my $found = wait_for_readable($receiver);
            ok($found, "$p: didn't time out while waiting for data $msg");

            if ($found) {
                $receiver->recv(my $buf, 256);

                ok($buf =~ /^<38>/, "$p: ->send $msg has the right priority");
                ok($buf =~ /$msg$/, "$p: ->send $msg has the right message");
                ok(payload_ok($buf, LOG_RFC3164, @payload_params), "$p: ->send $msg has correct payload");
            }
        }
    };
    #diag($@) if $@;

    # write accessors
    eval {

        my $server = $listen->();
        my $logger = $server->connect('Log::Syslog::Fast::PP' => @params);

        # ignore first connection for stream protos since reconnect is expected
        $server->accept();

        eval {
            # this method triggers a reconnect for stream protocols
            $logger->set_receiver($server->proto, $server->address);
        };
        ok(!$@, "$p: ->set_receiver doesn't throw");

        eval { $logger->set_priority(LOG_NEWS, LOG_CRIT) };
        ok(!$@, "$p: ->set_priority doesn't throw");

        eval { $logger->set_sender('otherhost') };
        ok(!$@, "$p: ->set_sender doesn't throw");

        eval { $logger->set_name('test2') };
        ok(!$@, "$p: ->set_name doesn't throw");

        eval { $logger->set_pid(12345) };
        ok(!$@, "$p: ->set_pid doesn't throw");

        my $receiver = $server->accept;

        my $msg = "testing 3";
        my @payload_params = (LOG_NEWS, LOG_CRIT, 'otherhost', 'test2', 12345, $msg, time);
        my $expected = expected_payload(@payload_params, LOG_RFC3164);

        my $sent = eval { $logger->send($msg) };
        ok(!$@, "$p: ->send after accessors doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while listening");

        if ($found) {
            $receiver->recv(my $buf, 256);
            ok($buf, "$p: send after set_receiver went to correct port");
            ok($buf =~ /^<58>/, "$p: ->send after set_priority has the right priority");
            ok($buf =~ /otherhost/, "$p: ->send after set_sender has the right sender");
            ok($buf =~ /test2\[/, "$p: ->send after set_name has the right name");
            ok($buf =~ /\[12345\]/, "$p: ->send after set_name has the right pid");
            ok($buf =~ /$msg$/, "$p: ->send after accessors sends right message");
            ok(payload_ok($buf, LOG_RFC3164, @payload_params), "$p: ->send $msg has correct payload");
        }
    };
    #diag($@) if $@;

    # RFC5424 format
    eval {

        my $server = $listen->();
        my $logger = $server->connect('Log::Syslog::Fast::PP' => @params);

        # ignore first connection for stream protos since reconnect is expected
        $server->accept();

        eval {
            # this method triggers a reconnect for stream protocols
            $logger->set_receiver($server->proto, $server->address);
        };
        ok(!$@, "$p: ->set_receiver doesn't throw");

        eval { $logger->set_priority(LOG_NEWS, LOG_CRIT) };
        ok(!$@, "$p: ->set_priority doesn't throw");

        eval { $logger->set_sender('otherhost') };
        ok(!$@, "$p: ->set_sender doesn't throw");

        eval { $logger->set_name('test2') };
        ok(!$@, "$p: ->set_name doesn't throw");

        eval { $logger->set_pid(12345) };
        ok(!$@, "$p: ->set_pid doesn't throw");

        eval { $logger->set_format(LOG_RFC5424) };
        ok(!$@, "$p: ->set_format doesn't throw");

        my $receiver = $server->accept;

        my $msg = "testing 3";
        my @payload_params = (LOG_NEWS, LOG_CRIT, 'otherhost', 'test2', 12345, $msg, time);
        my $expected = expected_payload(@payload_params, LOG_RFC5424);

        my $sent = eval { $logger->send($msg) };
        ok(!$@, "$p: ->send after accessors doesn't throw");
        is($sent, length $expected, "$p: ->send sent whole payload");

        my $found = wait_for_readable($receiver);
        ok($found, "$p: didn't time out while listening");

        if ($found) {
            $receiver->recv(my $buf, 256);
            ok($buf, "$p: send after set_receiver went to correct port");
            ok($buf =~ /^<58>1/, "$p: ->send after set_priority has the right priority");
            ok($buf =~ / otherhost /, "$p: ->send after set_sender has the right sender");
            ok($buf =~ / test2 /, "$p: ->send after set_name has the right name");
            ok($buf =~ / 12345 /, "$p: ->send after set_name has the right pid");
            ok($buf =~ / $msg$/, "$p: ->send after accessors sends right message");
            ok(payload_ok($buf, LOG_RFC5424, @payload_params), "$p: ->send $msg has correct payload");
        }
    };
    #diag($@) if $@;
}

# test LOG_UNIX with nonexistent/non-sock endpoint
{
    my $filename = "$test_dir/fake";

    my $fake_server = DgramServer->new(
        listener    => 1,
        proto       => LOG_UNIX,
        address     => [$filename, 0],
    );

    eval {
        $fake_server->connect('Log::Syslog::Fast::PP' => @params);
    };
    # "No such file"
    like($@, qr/Error in ->/, 'unix: ->new with missing file throws');

    open my $fh, '>', $filename or die "couldn't create fake socket $filename: $!";

    eval { $fake_server->connect('Log::Syslog::Fast::PP' => @params); };
    # "Connection refused"
    like($@, qr/Error in ->/, 'unix: ->new with non-sock throws');
}

# check that bad methods are reported for the caller
eval {
    my $logger = Log::Syslog::Fast::PP->new(LOG_UDP, 'localhost', 514, LOG_LOCAL0, LOG_INFO, "mymachine", "logger");
    $logger->nonexistent_method();
};
like($@, qr{at t/07-Log-Syslog-Fast-PP.t}, 'error in caller'); # not Fast.pm

sub expected_payload {
    my ($facility, $severity, $sender, $name, $pid, $msg, $time, $format) = @_;
    my $time_format = "%h %e %T";
    my $msg_format = "<%d>%s %s %s[%d]: %s";

    if ($format == LOG_RFC5424) {
        $time_format = "%Y-%m-%dT%H:%M:%S%z";
        $msg_format = "<%d>1 %s %s %s %d - - %s";
    }

    return sprintf $msg_format,
        ($facility << 3) | $severity,
        strftime($time_format, localtime($time)),
        $sender, $name, $pid, $msg;
}

sub payload_ok {
    my ($payload, $format, @payload_params) = @_;
    for my $offset (0, -1, 1) {
        my $allowed = expected_payload(@payload_params, $format);
        return 1 if $allowed eq $payload;
    }
    return 0;
}

# use select so test won't block on failure
sub wait_for_readable {
    my $sock = shift;
    return IO::Select->new($sock)->can_read(1);
}

# vim: filetype=perl
