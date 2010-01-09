#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "FastSyslogger.h"

#include "const-c.inc"

MODULE = Log::Syslog::Fast		PACKAGE = Log::Syslog::Fast

INCLUDE: const-xs.inc

PROTOTYPES: ENABLE

FastSyslogger*
FastSyslogger::new(proto, hostname, port, facility, severity, sender, name);
    int proto
    char* hostname
    int port
    int facility
    int severity
    char* sender
    char* name
CODE:
    try {
        RETVAL = new FastSyslogger(proto, hostname, port, facility, severity, sender, name);
    }
    catch (...) {
        // squash exceptions and return undef on failure
        XSRETURN_UNDEF;
    }
    if (!RETVAL) XSRETURN_UNDEF;
OUTPUT:
    RETVAL

void
FastSyslogger::DESTROY()

int
FastSyslogger::send(logmsg, now = time(0))
    char* logmsg
    time_t now
ALIAS:
    Log::Syslog::Fast::emit = 1
CODE:
    try {
        RETVAL = THIS->send(logmsg, strlen(logmsg), now);
    }
    catch (const char*& s) {
        croak("Error while sending: %s (%s)", s, strerror(errno));
    }
    if (!RETVAL) XSRETURN_UNDEF;
OUTPUT:
    RETVAL

void
FastSyslogger::setReceiver(proto, hostname, port)
    int proto
    char* hostname
    int port
ALIAS:
    Log::Syslog::Fast::set_receiver = 1
CODE:
    try {
        THIS->setReceiver(proto, hostname, port);
    }
    catch (const char*& s) {
        croak("Error in set_receiver: %s (%s)", s, strerror(errno));
    }

void
FastSyslogger::setPriority(facility, severity)
    int facility
    int severity
ALIAS:
    Log::Syslog::Fast::set_priority = 1

void
FastSyslogger::setSender(sender)
    char* sender
ALIAS:
    Log::Syslog::Fast::set_sender = 1

void
FastSyslogger::setName(name)
    char* name
ALIAS:
    Log::Syslog::Fast::set_name = 1

void
FastSyslogger::setPid(pid)
    int pid
ALIAS:
    Log::Syslog::Fast::set_pid = 1
