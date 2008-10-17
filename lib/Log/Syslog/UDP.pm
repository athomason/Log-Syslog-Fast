package Log::Syslog::UDP;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ();
our @EXPORT_OK = ();
our @EXPORT = qw();

our $VERSION = '0.03';

require XSLoader;
XSLoader::load('Log::Syslog::UDP', $VERSION);

1;
__END__

=head1 NAME

Log::Syslog::UDP - Perl extension for very quickly sending syslog messages over UDP.

=head1 SYNOPSIS

  use Log::Syslog::UDP;
  my $logger = Log::Syslog::UDP->new("127.0.0.1", 514, 16, 6, "mymachine", "logger");
  $logger->send("log message", time);

=head1 DESCRIPTION

This module sends syslog messages over a non-blocking UDP socket.

=head1 METHODS

=over 4

=item UDPSyslogger-E<gt>new($hostname, $port, $facility, $severity, $sender, $name);

Create a new UDPSyslogger object with the following parameters:

=over 4

=item $hostname

The destination hostname where a syslogd is running.

=item $port

The destination port where a syslogd is listening. Usually 514.

=item $facility

The syslog facility constant, eg 16 for 'local0'.

=item $severity

The syslog facility constant, eg 6 for 'info'.

=item $sender

The originating hostname. Sys::Hostname::hostname is a reasonable source for this.

=item $name

The program name or tag to use for the message.

=back

=item $logger-E<gt>send($logmsg, [$time])

Send a syslog message through the configured logger. Provide $time if you know,
otherwise time() will be called for you.

=back

=head1 EXPORT

None.

=head1 SEE ALSO

L<Sys::Syscall> is much more flexible, but a lot slower.

=head1 AUTHOR

Adam Thomason, E<lt>athomason@sixapart.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Six Apart, Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
