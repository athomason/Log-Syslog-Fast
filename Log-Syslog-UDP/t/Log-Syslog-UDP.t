use strict;
use warnings;

use Test::More tests => 33;

BEGIN { use_ok('Log::Syslog::UDP', ':all') };

my $logger = Log::Syslog::UDP->new("127.0.0.1", 514, 4, 6, "localhost", "test");
ok($logger, "->new returns something");
is(ref $logger, 'Log::Syslog::UDP', '->new returns a Log::Syslog::UDP object');
eval {
    $logger->send("testing ", time);
};
ok(!$@, "->send doesn't throw");

eval {
    $logger->send("testing ");
};
ok(!$@, "->send without time doesn't throw");

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
