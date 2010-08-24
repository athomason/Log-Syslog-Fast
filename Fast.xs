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
FSL_alloc()
CODE:
    RETVAL = FSL_alloc();
    if (!RETVAL) XSRETURN_UNDEF;
OUTPUT:
    RETVAL

int
FSL_init(logger, proto, hostname, port, facility, severity, sender, name)
    FastSyslogger* logger
    int proto
    char* hostname
    int port
    int facility
    int severity
    char* sender
    char* name

void
FSL_destroy(logger)
    FastSyslogger* logger

int
FSL_send(logger, logmsg, now)
    FastSyslogger* logger
    char* logmsg
    time_t now
CODE:
    RETVAL = FSL_send(logger, logmsg, strlen(logmsg), now);
OUTPUT:
    RETVAL

int
FSL_set_receiver(logger, proto, hostname, port)
    FastSyslogger* logger
    int proto
    char* hostname
    int port

void
FSL_set_priority(logger, facility, severity)
    FastSyslogger* logger
    int facility
    int severity

void
FSL_set_sender(logger, sender)
    FastSyslogger* logger
    char* sender

void
FSL_set_name(logger, name)
    FastSyslogger* logger
    char* name

void
FSL_set_pid(logger, pid)
    FastSyslogger* logger
    int pid

char*
FSL_error(logger)
    FastSyslogger* logger
CODE:
    RETVAL = logger->err;
OUTPUT:
    RETVAL
