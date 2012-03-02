use strict;
use warnings;

use Log::Syslog::Fast qw(:all);
use Test::More tests => 7;

my $logger;
{
    local $@ = undef;
    eval {
        $logger = Log::Syslog::Fast::new(
            undef, LOG_UDP, 'localhost', 514,
            LOG_LOCAL0, LOG_INFO, "mymachine", "logger"
        );
    };
    ok(!$@, 'no exception thrown in ->new with missing class');
};

{
    local $@ = undef;
    eval {
        Log::Syslog::Fast->new(
            LOG_UDP, undef, 514,
            LOG_LOCAL0, LOG_INFO, "mymachine", "logger"
        );
    };
    ok($@, 'exception thrown in ->new with missing host');
};

{
    local $@ = undef;
        eval {
        Log::Syslog::Fast->new(
            LOG_UDP, 'localhost', 514,
            LOG_LOCAL0, LOG_INFO, undef, "logger"
        );
    };
    ok($@, 'exception thrown in ->new with missing sender');
};

{
    local $@ = undef;
    eval {
        Log::Syslog::Fast->new(
            LOG_UDP, 'localhost', 514,
            LOG_LOCAL0, LOG_INFO, "mymachine", undef
        );
    };
    ok($@, 'exception thrown in ->new with missing name');
};

{
    local $@ = undef;
    eval {
        $logger->set_name(undef);
    };
    ok($@, 'exception thrown in ->set_name');
};

{
    local $@ = undef;
    eval {
        $logger->set_receiver(undef);
    };
    ok($@, 'exception thrown in ->set_receiver');
};

{
    local $@ = undef;
    eval {
        $logger->set_sender(undef);
    };
    ok($@, 'exception thrown in ->set_sender');
};
