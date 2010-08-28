use strict;
use warnings;

use Test::More tests => 142;
use File::Temp 'tempdir';
use IO::Select;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Log::Syslog::Constants ':all';
use POSIX 'strftime';

BEGIN { use_ok('Log::Syslog::Fast', ':protos') };

my $test_dir = tempdir(CLEANUP => 1);

# old IO::Socket::INET fails with "Bad service '0'" when attempting to use
# wildcard port
my $port = 24767;
sub listen_port {
    return 0 if $IO::Socket::INET::VERSION >= 1.31;
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
    eval { Log::Syslog::Fast->new($proto, '%^!/0', 0, @params) };
    like($@, qr/^Error in ->new/, "$proto: bad ->new call throws an exception");
}

for my $p (sort keys %servers) {
    my $listen = $servers{$p};

    # basic behavior
    eval {
        my $server = $listen->();
        ok($server->{listener}, "$p: listen") or diag("listen failed: $!");

        my $logger = $server->connect(@params);
        ok($logger, "$p: ->new returns something");
        is(ref $logger, 'Log::Syslog::Fast', "$p: ->new returns a Log::Syslog::Fast object");

        my $receiver = $server->accept;
        ok($receiver, "$p: accepted");

        my $time = time;
        for my $config (['without time'], ['with time', $time]) {
            my ($msg, @extra) = @$config;

            my $expected = expected_payload(@params, $$, $msg, $time);

            my $sent = eval { $logger->send($msg, @extra) };
            ok(!$@, "$p: ->send $msg doesn't throw");
            is($sent, length $expected, "$p: ->send $msg sent whole payload");

            my $found = wait_for_readable($receiver);
            ok($found, "$p: didn't time out while waiting for data $msg");

            if ($found) {
                $receiver->recv(my $buf, 256);

                ok($buf =~ /^<38>/, "$p: ->send $msg has the right priority");
                ok($buf =~ /$msg$/, "$p: ->send $msg has the right message");
                is($buf, $expected, "$p: ->send $msg has correct payload");
            }
        }
    };
    diag($@) if $@;

    # write accessors
    eval {

        my $server = $listen->();
        my $logger = $server->connect(@params);

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
        my $expected = expected_payload(LOG_NEWS, LOG_CRIT, 'otherhost', 'test2', 12345, $msg, time);

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
            is($buf, $expected, "$p: ->send after accessors has right payload");
        }
    };
    diag($@) if $@;

    # test failure behavior when server is unreachable
    eval {

        # test when server is initially available but goes away
        my $server = $listen->();
        my $logger = $server->connect(@params);
        $server->close();

        my $piped = 0;
        local $SIG{PIPE} = sub { $piped++ };
        eval { $logger->send("testclosed") };
        if ($p eq 'tcp') {
            # "Connection reset by peer" on linux, sigpipe on bsds
            ok($@ || $piped, "$p: ->send throws on server close");
        }
        elsif ($p eq 'udp') {
            ok(!$@, "$p: ->send doesn't throw on server close");
        }
        elsif ($p eq 'unix_dgram') {
            # "Connection refused"
            like($@, qr/Error while sending/, "$p: ->send throws on server close");
        }
        elsif ($p eq 'unix_stream') {
            ok($piped, "$p: ->send raises SIGPIPE on server close");
        }

        # test when server is not initially available

        # increment peer port to get one that (probably) wasn't recently used;
        # otherwise UDP/ICMP business doesn't work right on at least linux 2.6.18
        $server->{address}[1]++;

        if ($p eq 'udp') {
            # connectionless udp should fail on 2nd call to ->send, after ICMP
            # error is noticed by kernel

            my $logger = $server->connect(@params);
            ok($logger, "$p: ->new doesn't throw on connect to missing server");

            for my $n (1..2) {
                eval { $logger->send("test$n") };
                ok(!$@, "$p: odd ->send to missing server doesn't throw");

                eval { $logger->send("test$n") };
                # "Connection refused"
                like($@, qr/Error while sending/, "$p: even ->send to missing server does throw");
            }
        }
        else {
            # connected protocols should fail on connect, i.e. ->new
            eval { Log::Syslog::Fast->new($server->proto, $server->address, @params); };
            like($@, qr/^Error in ->new/, "$p: ->new throws on connect to missing server");
        }
    };
    diag($@) if $@;
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
        $fake_server->connect(@params);
    };
    # "No such file"
    like($@, qr/Error in ->new/, 'unix: ->new with missing file throws');

    open my $fh, '>', $filename or die "couldn't create fake socket $filename: $!";

    eval { $fake_server->connect(@params); };
    # "Connection refused"
    like($@, qr/Error in ->new/, 'unix: ->new with non-sock throws');
}

sub expected_payload {
    my ($facility, $severity, $sender, $name, $pid, $msg, $time) = @_;
    return sprintf "<%d>%s %s %s[%d]: %s",
        ($facility << 3) | $severity,
        strftime("%h %e %T", localtime($time)),
        $sender, $name, $pid, $msg;
}

# use select so test won't block on failure
sub wait_for_readable {
    my $sock = shift;
    return IO::Select->new($sock)->can_read(1);
}

package ServerCreator;

sub new {
    my $class = shift;
    return bless {label => $_[0], listen => $_[1]}, $class;
}


sub listen {
    my $self = shift;
    $self->{listen}->();
}

package Server;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}
sub proto {
    my $self = shift;
    return $self->{proto};
}

sub address {
    my $self = shift;
    return @{ $self->{address} };
}

sub connect {
    my $self = shift;
    return Log::Syslog::Fast->new($self->proto, $self->address, @_);
}

sub close {
    my $self = shift;
    $self->{listener} = undef;
}

# remove unix socket file on server close
sub DESTROY {
    my $self = shift;
    if ($self->{address}[1] == 0) {
        unlink $self->{address}[0];
    }
}

package StreamServer;

use base 'Server';

sub accept {
    my $self = shift;
    my $receiver = $self->{listener}->accept;
    $receiver->blocking(0);
    return $receiver;
}

package DgramServer;

use base 'Server';

sub accept {
    my $self = shift;
    return $self->{listener};
}

# vim: filetype=perl
