package Log::Syslog::Fast::XS;

use 5.006002;
use strict;
use warnings;

require Exporter;
use Log::Syslog::Constants ();
use Carp 'croak';

our $VERSION = '0.56';

require XSLoader;
XSLoader::load('Log::Syslog::Fast::XS', $VERSION);

1;
__END__

=head1 NAME

Log::Syslog::Fast::XS - XS implementation of Log::Syslog::Fast

=head1 DESCRIPTION

This is the XS implementation of L<Log::Syslog::Fast>. See its documentation
for usage.

=head1 AUTHOR

Adam Thomason, E<lt>athomason@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Say Media, Inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
