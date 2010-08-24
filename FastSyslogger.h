#ifndef __FASTSYSLOG_H__
#define __FASTSYSLOG_H__

#include <time.h>

#define LOG_BUFSIZE 16384

typedef struct {

    // configuration
    int    priority_;                // RFC3164/4.1.1 PRI Part
    char   sender_[LOG_BUFSIZE];     // sender hostname
    char   name_[LOG_BUFSIZE];       // sending program name
    int    pid_;                     // sending program pid

    // resource handles
    int    sock_;                    // socket fd

    // internal state
    time_t last_time_;               // time when the prefix was last generated
    char   linebuf_[LOG_BUFSIZE];    // log line, including prefix and message
    size_t prefix_len_;              // length of the prefix string
    char*  msg_start_;               // pointer into linebuf_ after end of prefix

    // error reporting
    char*  err_;

} FastSyslogger;

FastSyslogger* FastSyslogger_alloc();
int FastSyslogger_init(FastSyslogger* logger, int proto, char* hostname, int port, int facility, int severity, char* sender, char* name);
int FastSyslogger_destroy(FastSyslogger* logger);

int FastSyslogger_setReceiver(FastSyslogger* logger, int proto, char* hostname, int port);
void FastSyslogger_setPriority(FastSyslogger* logger, int facility, int severity);
void FastSyslogger_setSender(FastSyslogger* logger, char* sender);
void FastSyslogger_setName(FastSyslogger* logger, char* name);
void FastSyslogger_setPid(FastSyslogger* logger, int pid);

int FastSyslogger_send(FastSyslogger* logger, char* msg, int len, time_t t);

#endif
