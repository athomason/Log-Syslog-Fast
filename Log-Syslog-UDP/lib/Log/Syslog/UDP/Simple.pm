package Log::Syslog::UDP::Simple;

use strict;
use warnings;

use Log::Syslog::UDP ':all';
use Sys::Hostname;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = %Log::Syslog::UDP::EXPORT_TAGS;
our @EXPORT_OK   = @Log::Syslog::UDP::EXPORT_OK;
our @EXPORT      = qw();

use constant {
    _LOGGERS    => 0,
    _ARGS       => 1,

    _HOSTNAME   => 0,
    _PORT       => 1,
    _FACILITY   => 2,
    _SEVERITY   => 3,
    _SENDER     => 4,
    _NAME       => 5,
};

sub new {
    my $what = shift;
    my $class = ref $what || $what;

    my $default_name = $0;
    $default_name =~ s,.*/,,;
    $default_name =~ s/[^\w.-_]//g;

    my $args = (@_ == 1 && ref $_[0] eq 'HASH') ? $_[0] : {@_};

    $args->{hostname}   ||= '127.0.0.1';
    $args->{port}       ||= 514;
    $args->{facility}   ||= LOG_LOCAL0;
    $args->{severity}   ||= LOG_INFO;
    $args->{sender}     ||= Sys::Hostname::hostname;
    $args->{name}       ||= $default_name;

    return bless [
        [],    # loggers
        [@{ $args }{qw/ 
            hostname port facility severity sender name
        /}],
    ], $class;
}

sub send {
    my $severity = $_[3] || $_[0][_ARGS][_SEVERITY];
    my $facility = $_[4] || $_[0][_ARGS][_FACILITY];

    my $logger = $_[0][_LOGGERS][$facility][$severity];
    if (!$logger) {
        my @args = @{ $_[0][_ARGS] };
        $args[_FACILITY] = $facility;
        $args[_SEVERITY] = $severity;

        $logger = $_[0][_LOGGERS][$facility][$severity] = Log::Syslog::UDP->new(@args);
    }

    return $logger->send($_[1], $_[2] || time);
}

1;
__END__

=head1 NAME

Log::Syslog::UDP::Simple - Wrapper around Log::Syslog::UDP that adds some
flexibility at the expense of additional runtime overhead.

=head1 SYNOPSIS

  use Log::Syslog::UDP::Simple;

  # Simple usage:
  $logger = Log::Syslog::UDP::Simple->new;
  $logger->send("log message");

  # More customized usage:
  $logger = Log::Syslog::UDP::Simple->new(
      loghost  => 'myloghost',
      port     => 6666,
      facility => LOG_LOCAL2, 
      severity => LOG_INFO,
      sender   => 'mymachine',
      name     => 'myapp',
  ); 
  $logger->send("log message", time, LOG_LOCAL3, LOG_DEBUG);

=head1 DESCRIPTION

This module wraps L<Log::Syslog::UDP> to provide a constructor with reasonable
defaults and a send() method that optionally accepts override parameters for
facility and severity.

=head1 METHODS

=over 4

=item Log::Syslog::UDP::Simple-E<gt>new(%params);

Create a new Log::Syslog::UDP::Simple object with given parameters (may be a
hash or hashref). Takes the following named parameters which have the same
meaning as in Log::Syslog::UDP.

=over 4

=item loghost

Defaults to 127.0.0.1

=item port

Defaults to 514

=item facility

Defaults to LOG_LOCAL0

=item severity

Defaults to LOG_INFO

=item sender

Defaults to Sys::Hostname::hostname

=item name

Defaults to a cleaned $0 

=back

=item $logger-E<gt>send($logmsg, [$time], [$severity], [$facility])

Send a syslog message through the configured logger. If $time is not provided,
the current time is used. If $severity or $facility are not provided, the
default provided at construction time is used.

=back

=head1 EXPORT

Same as Log::Syslog::UDP.

=head1 SEE ALSO

L<Log::Syslog::UDP>

=head1 AUTHOR

Adam Thomason, E<lt>athomason@sixapart.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Six Apart, Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
