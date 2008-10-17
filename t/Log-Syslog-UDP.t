use Test::More tests => 5;
BEGIN { use_ok('Log::Syslog::UDP') };

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
