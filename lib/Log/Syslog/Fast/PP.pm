package Log::Syslog::Fast::PP;

use 5.006002;
use strict;
use warnings;

require Exporter;
use Carp 'croak';

our @ISA = qw(Exporter);

# protocols
use constant LOG_UDP    => 0; # UDP
use constant LOG_TCP    => 1; # TCP
use constant LOG_UNIX   => 2; # UNIX socket

# format
use constant LOG_RFC3164 => 0;
use constant LOG_RFC5424 => 1;

use POSIX 'strftime';
use IO::Socket::INET;
use IO::Socket::UNIX;

our %EXPORT_TAGS = (
    protos => [qw/ LOG_TCP LOG_UDP LOG_UNIX /],
    formats => [qw/ LOG_RFC3164 LOG_RFC5424 /],
);
push @{ $EXPORT_TAGS{'all'} }, @{ $EXPORT_TAGS{'protos'} };
push @{ $EXPORT_TAGS{'all'} }, @{ $EXPORT_TAGS{'formats'} };

our @EXPORT_OK = @{ $EXPORT_TAGS{'all'} };
our @EXPORT = qw();

use constant PRIORITY   => 0;
use constant SENDER     => 1;
use constant NAME       => 2;
use constant PID        => 3;
use constant SOCK       => 4;
use constant LAST_TIME  => 5;
use constant PREFIX     => 6;
use constant PREFIX_LEN => 7;
use constant FORMAT     => 8;

sub new {
    my $ref = shift;
    my $class = ref $ref || $ref;

    my ($proto, $hostname, $port, $facility, $severity, $sender, $name) = @_;

    my $self = bless [
        ($facility << 3) | $severity, # prio
        $sender, # sender
        $name, # name
        $$, # pid
        undef, # sock
        undef, # last_time
        undef, # prefix
        undef, # prefix_len
        LOG_RFC3164, # format
    ], $class;

    $self->update_prefix(time());

    $self->set_receiver($proto, $hostname, $port);

    return $self;
}

sub update_prefix {
    my $self = shift;
    my $t = shift;

    $self->[LAST_TIME] = $t;

    my $timestr = strftime("%h %e %T", localtime $t);
    if ($self->[FORMAT] == LOG_RFC5424) {
        $timestr = strftime("%Y-%m-%dT%H:%M:%S%z", localtime $t);
    }

    $self->[PREFIX] = sprintf "<%d>%s %s %s[%d]: ",
        $self->[PRIORITY], $timestr, $self->[SENDER], $self->[NAME], $self->[PID];
    if ($self->[FORMAT] == LOG_RFC5424) {
        $self->[PREFIX] = sprintf "<%d>1 %s %s %s %d - - ",
            $self->[PRIORITY], $timestr, $self->[SENDER], $self->[NAME], $self->[PID];
    }
}

sub set_receiver {
    my $self = shift;
    my ($proto, $hostname, $port) = @_;

    if ($proto == LOG_TCP) {
        $self->[SOCK] = IO::Socket::INET->new(
            Proto    => 'tcp',
            PeerHost => $hostname,
            PeerPort => $port,
        );
    }
    elsif ($proto == LOG_UDP) {
        $self->[SOCK] = IO::Socket::INET->new(
            Proto    => 'udp',
            PeerHost => $hostname,
            PeerPort => $port,
        );
    }
    elsif ($proto == LOG_UNIX) {
        eval {
            $self->[SOCK] = IO::Socket::UNIX->new(
                Proto => SOCK_STREAM,
                Peer  => $hostname,
            );
        };
        if ($@ || !$self->[SOCK]) {
            $self->[SOCK] = IO::Socket::UNIX->new(
                Proto => SOCK_DGRAM,
                Peer  => $hostname,
            );
        }
    }

    die "Error in ->set_receiver: $!" unless $self->[SOCK];
}

sub set_priority {
    my $self = shift;
    my ($facility, $severity) = @_;
    $self->[PRIORITY] = ($facility << 3) | $severity;
    $self->update_prefix(time);
}

sub set_facility {
    my $self = shift;
    $self->set_priority(shift, $self->get_severity);
}

sub set_severity {
    my $self = shift;
    $self->set_priority($self->get_facility, shift);
}

sub set_sender {
    my $self = shift;
    $self->[SENDER] = shift;
    $self->update_prefix(time);
}

sub set_name {
    my $self = shift;
    $self->[NAME] = shift;
    $self->update_prefix(time);
}

sub set_pid {
    my $self = shift;
    $self->[PID] = shift;
    $self->update_prefix(time);
}

sub set_format {
    my $self = shift;
    $self->[FORMAT] = shift;
    $self->update_prefix(time);
}

sub send {
    my $now = $_[2] || time;

    # update the prefix if seconds have rolled over
    if ($now != $_[0][LAST_TIME]) {
        $_[0]->update_prefix($now);
    }

    send $_[0][SOCK], $_[0][PREFIX] . $_[1], 0;
}

sub get_priority {
    my $self = shift;
    return $self->[PRIORITY];
}

sub get_facility {
    my $self = shift;
    return $self->[PRIORITY] >> 3;
}

sub get_severity {
    my $self = shift;
    return $self->[PRIORITY] & 7;
}

sub get_sender {
    my $self = shift;
    return $self->[SENDER];
}

sub get_name {
    my $self = shift;
    return $self->[NAME];
}

sub get_pid {
    my $self = shift;
    return $self->[PID];
}

sub get_format {
    my $self = shift;
    return $self->[FORMAT];
}

1;
__END__

=head1 NAME

Log::Syslog::Fast::PP - XS-free, API-compatible version of Log::Syslog::Fast

=head1 SYNOPSIS

  use Log::Syslog::Fast::PP ':all';
  my $logger = Log::Syslog::Fast::PP->new(LOG_UDP, "127.0.0.1", 514, LOG_LOCAL0, LOG_INFO, "mymachine", "logger");
  $logger->send("log message", time);

=head1 DESCRIPTION

This module should be fully API-compatible with L<Log::Syslog::Fast>; refer to
its documentation for usage.

=head1 AUTHOR

Adam Thomason, E<lt>athomason@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Say Media, Inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
