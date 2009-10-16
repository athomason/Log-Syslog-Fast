package Log::Syslog::Fast;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

use constant {
    # protocols
    LOG_UDP         => 0, # UDP
    LOG_TCP         => 1, # TCP

    # severities
    LOG_EMERG       => 0, # system is unusable
    LOG_ALERT       => 1, # action must be taken immediately
    LOG_CRIT        => 2, # critical conditions
    LOG_ERR         => 3, # error conditions
    LOG_WARNING     => 4, # warning conditions
    LOG_NOTICE      => 5, # normal but significant condition
    LOG_INFO        => 6, # informational
    LOG_DEBUG       => 7, # debug-level messages

    # facilities
    LOG_KERN        => 0, # kernel messages
    LOG_USER        => 1, # random user-level messages
    LOG_MAIL        => 2, # mail system
    LOG_DAEMON      => 3, # system daemons
    LOG_AUTH        => 4, # security/authorization messages
    LOG_SYSLOG      => 5, # messages generated internally by syslogd
    LOG_LPR         => 6, # line printer subsystem
    LOG_NEWS        => 7, # network news subsystem
    LOG_UUCP        => 8, # UUCP subsystem
    LOG_CRON        => 9, # clock daemon
    LOG_AUTHPRIV    => 10, # security/authorization messages (private)
    LOG_FTP         => 11, # ftp daemon
    LOG_LOCAL0      => 16, # reserved for local use
    LOG_LOCAL1      => 17, # reserved for local use
    LOG_LOCAL2      => 18, # reserved for local use
    LOG_LOCAL3      => 19, # reserved for local use
    LOG_LOCAL4      => 20, # reserved for local use
    LOG_LOCAL5      => 21, # reserved for local use
    LOG_LOCAL6      => 22, # reserved for local use
    LOG_LOCAL7      => 23, # reserved for local use
};

our %EXPORT_TAGS = (
    protos   => [qw/
        LOG_TCP LOG_UDP
    /],
    facilities   => [qw/
        LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING
        LOG_NOTICE LOG_INFO LOG_DEBUG
    /],
    severities => [qw/
        LOG_KERN LOG_USER LOG_MAIL LOG_DAEMON LOG_AUTH
        LOG_SYSLOG LOG_LPR LOG_NEWS LOG_UUCP LOG_CRON
        LOG_AUTHPRIV LOG_FTP LOG_LOCAL0 LOG_LOCAL1 LOG_LOCAL2
        LOG_LOCAL3 LOG_LOCAL4 LOG_LOCAL5 LOG_LOCAL6 LOG_LOCAL7
    /],
);
@{ $EXPORT_TAGS{'all'} } = (
    @{ $EXPORT_TAGS{'protos'} },
    @{ $EXPORT_TAGS{'facilities'} },
    @{ $EXPORT_TAGS{'severities'} }
);

our @EXPORT_OK = @{ $EXPORT_TAGS{'all'} };
our @EXPORT = qw();

our $VERSION = '0.24';

require XSLoader;
XSLoader::load('Log::Syslog::Fast', $VERSION);

1;
__END__

=head1 NAME

Log::Syslog::Fast - Perl extension for sending syslog messages over TCP or UDP
with minimal CPU overhead.

=head1 SYNOPSIS

  use Log::Syslog::Fast ':all';
  my $logger = Log::Syslog::Fast->new(LOG_UDP, "127.0.0.1", 514, LOG_LOCAL0, LOG_INFO, "mymachine", "logger");
  $logger->send("log message", time);

=head1 DESCRIPTION

This module sends syslog messages over a network socket. It works like
L<Sys::Syslog> in setlogsock's 'udp' or 'tcp' modes, but without the
significant CPU overhead of that module when used for high-volume logging. Use
of this specialized module is only recommended if 1) you must use network
syslog as a messaging transport but 2) need to minimize the time spent in the
logger.

This module supercedes the less general L<Log::Syslog::UDP>.

=head1 METHODS

=over 4

=item Log::Syslog::Fast-E<gt>new($proto, $hostname, $port, $facility, $severity, $sender, $name);

Create a new Log::Syslog::Fast object with the following parameters:

=over 4

=item $proto

The transport protocol, either LOG_TCP or LOG_UDP.

If LOG_TCP is used, calls to $logger-E<gt>send() will block until remote
receipt of the message is confirmed. If LOG_UDP is used, the call will never
block and may fail if insufficient buffer space exists in the network stack.

=item $hostname

The destination hostname where a syslogd is running.

=item $port

The destination port where a syslogd is listening. Usually 514.

=item $facility

The syslog facility constant, eg 16 for 'local0'. See RFC3164 section 4.1.1 (or
E<lt>sys/syslog.hE<gt>) for appropriate constant values.

=item $severity

The syslog severity constant, eg 6 for 'info'. See RFC3164 section 4.1.1 (or
E<lt>sys/syslog.hE<gt>) for appropriate constant values.

=item $sender

The originating hostname. Sys::Hostname::hostname is typically a reasonable
source for this.

=item $name

The program name or tag to use for the message.

=back

=item $logger-E<gt>send($logmsg, [$time])

=item $logger-E<gt>emit($logmsg, [$time])

Send a syslog message through the configured logger. If $time is not provided,
CORE::time() will be called for you. That doubles the syscalls per message, so
try to pass it if you're already calling time() yourself.

B<emit> is an alias for B<send>.

=head3 NEWLINE CAVEAT

Note that B<send> does not add any newline character(s) to its input. You will
certainly want to do this yourself for TCP connections, or the server will not
treat each message as a separate line. However with UDP the server should
accept a message without a trailing newline (though some implementations may
have difficulty with that).

=item $logger-E<gt>set_receiver($hostname, $port)

Change the destination host and port. This will force a reconnection in LOG_TCP
mode.

=item $logger-E<gt>set_priority($facility, $severity)

Change the syslog facility and severity.

=item $logger-E<gt>set_sender($sender)

Change what is sent as the hostname of the sender.

=item $logger-E<gt>set_name($name)

Change what is sent as the name of the sending program.

=item $logger-E<gt>set_pid($name)

Change what is sent as the process id of the sending program.

=back

=head1 EXPORT

You may optionally import constants for severity and facility levels.

  use Log::Syslog::Fast qw(:protos); # LOG_TCP and LOG_UDP
  use Log::Syslog::Fast qw(:severities); # LOG_CRIT, LOG_NOTICE, LOG_DEBUG, etc
  use Log::Syslog::Fast qw(:facilities); # LOG_CRON, LOG_LOCAL3, etc
  use Log::Syslog::Fast qw(:all); # all of the above

=head1 SEE ALSO

L<Sys::Syslog>

=head1 AUTHOR

Adam Thomason, E<lt>athomason@sixapart.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Six Apart, Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
