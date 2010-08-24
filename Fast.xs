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
FastSyslogger_alloc()
CODE:
    RETVAL = FastSyslogger_alloc();
    if (!RETVAL) XSRETURN_UNDEF;
OUTPUT:
    RETVAL

int
FastSyslogger_init(logger, proto, hostname, port, facility, severity, sender, name)
    FastSyslogger* logger
    int proto
    char* hostname
    int port
    int facility
    int severity
    char* sender
    char* name

void
FastSyslogger_destroy(logger)
    FastSyslogger* logger

int
FastSyslogger_send(logger, logmsg, now)
    FastSyslogger* logger
    char* logmsg
    time_t now
CODE:
    RETVAL = FastSyslogger_send(logger, logmsg, strlen(logmsg), now);
OUTPUT:
    RETVAL

int
FastSyslogger_setReceiver(logger, proto, hostname, port)
    FastSyslogger* logger
    int proto
    char* hostname
    int port

void
FastSyslogger_setPriority(logger, facility, severity)
    FastSyslogger* logger
    int facility
    int severity

void
FastSyslogger_setSender(logger, sender)
    FastSyslogger* logger
    char* sender

void
FastSyslogger_setName(logger, name)
    FastSyslogger* logger
    char* name

void
FastSyslogger_setPid(logger, pid)
    FastSyslogger* logger
    int pid

char*
FastSyslogger_error(logger)
    FastSyslogger* logger
CODE:
    RETVAL = logger->err_;
OUTPUT:
    RETVAL
