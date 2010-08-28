use 5.006002;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Log::Syslog::Fast',
    VERSION_FROM      => 'lib/Log/Syslog/Fast.pm', # finds $VERSION
    PREREQ_PM         => {
        'Log::Syslog::Constants'    => 1.01,
    },
    ABSTRACT_FROM     => 'lib/Log/Syslog/Fast.pm',
    AUTHOR            => 'Adam Thomason <athomason@cpan.org>',
    DEFINE            => '',
    INC               => '-I.',
    OBJECT            => 'LogSyslogFast.o Fast.o', # link all the C files too
    CCFLAGS           => '-g',
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw());
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'Log::Syslog::Fast',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
