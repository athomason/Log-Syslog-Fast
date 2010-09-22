#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "LogSyslogFast.h"

#include "const-c.inc"

MODULE = Log::Syslog::Fast		PACKAGE = Log::Syslog::Fast

INCLUDE: const-xs.inc

PROTOTYPES: ENABLE

LogSyslogFast*
new(class, proto, hostname, port, facility, severity, sender, name)
    char* class
    int proto
    char* hostname
    int port
    int facility
    int severity
    char* sender
    char* name
CODE:
    RETVAL = LSF_alloc();
    if (!RETVAL)
        croak("Error in ->new: malloc failed");
    if (LSF_init(RETVAL, proto, hostname, port, facility, severity, sender, name) < 0)
        croak("Error in ->new: %s", RETVAL->err);
OUTPUT:
    RETVAL

void
DESTROY(logger)
    LogSyslogFast* logger
CODE:
    if (LSF_destroy(logger))
        croak("Error in close: %s", logger->err);

int
send(logger, logmsg, now = time(0))
    LogSyslogFast* logger
    char* logmsg
    time_t now
ALIAS:
    emit = 1
CODE:
    RETVAL = LSF_send(logger, logmsg, strlen(logmsg), now);
    if (RETVAL < 0)
        croak("Error while sending: %s", logger->err);
OUTPUT:
    RETVAL

void
set_receiver(logger, proto, hostname, port)
    LogSyslogFast* logger
    int proto
    char* hostname
    int port
ALIAS:
    setReceiver = 1
CODE:
    int ret = LSF_set_receiver(logger, proto, hostname, port);
    if (ret < 0)
        croak("Error in set_receiver: %s", logger->err);

void
set_priority(logger, facility, severity)
    LogSyslogFast* logger
    int facility
    int severity
ALIAS:
    setPriority = 1
CODE:
    LSF_set_priority(logger, facility, severity);

void
set_sender(logger, sender)
    LogSyslogFast* logger
    char* sender
ALIAS:
    setSender = 1
CODE:
    LSF_set_sender(logger, sender);

void
set_name(logger, name)
    LogSyslogFast* logger
    char* name
ALIAS:
    setName = 1
CODE:
    LSF_set_name(logger, name);

void
set_pid(logger, pid)
    LogSyslogFast* logger
    int pid
ALIAS:
    setPid = 1
CODE:
    LSF_set_pid(logger, pid);
