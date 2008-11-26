#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "UDPSyslogger.h"

#include "const-c.inc"

MODULE = Log::Syslog::UDP		PACKAGE = Log::Syslog::UDP		

INCLUDE: const-xs.inc

PROTOTYPES: ENABLE

UDPSyslogger*
UDPSyslogger::new(hostname, port, facility, severity, sender, name);
    char* hostname
    int port
    int facility
    int severity
    char* sender
    char* name
    CODE:
        try {
            RETVAL = new UDPSyslogger(hostname, port, facility, severity, sender, name);
        }
        catch (...) {
            // squash exceptions and return undef on failure
        }
        if (!RETVAL) XSRETURN_UNDEF;
    OUTPUT:
        RETVAL

void
UDPSyslogger::DESTROY()

void
UDPSyslogger::send(logmsg, now = time(0))
    char* logmsg
    time_t now
ALIAS:
    Log::Syslog::UDP::emit = 1
CODE:
    THIS->send(logmsg, strlen(logmsg), now);

void
UDPSyslogger::setReceiver(hostname, port)
    char* hostname
    int port
ALIAS:
    Log::Syslog::UDP::set_receiver = 1

void
UDPSyslogger::setPriority(facility, severity)
    int facility
    int severity
ALIAS:
    Log::Syslog::UDP::set_priority = 1

void
UDPSyslogger::setSender(sender)
    char* sender
ALIAS:
    Log::Syslog::UDP::set_sender = 1

void
UDPSyslogger::setName(name)
    char* name
ALIAS:
    Log::Syslog::UDP::set_name = 1

void
UDPSyslogger::setPid(pid)
    int pid
ALIAS:
    Log::Syslog::UDP::set_pid = 1
