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

void
UDPSyslogger::setPriority(facility, severity)
    int facility
    int severity

void
UDPSyslogger::setSender(sender)
    char* sender

void
UDPSyslogger::setName(name)
    char* name
