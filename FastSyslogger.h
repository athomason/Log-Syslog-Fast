#ifndef __FASTSYSLOG_H__
#define __FASTSYSLOG_H__

#include <time.h>

#define LOG_BUFSIZE 16384

typedef struct {

    // configuration
    int    priority;                // RFC3164/4.1.1 PRI Part
    char   sender[LOG_BUFSIZE];     // sender hostname
    char   name[LOG_BUFSIZE];       // sending program name
    int    pid;                     // sending program pid

    // resource handles
    int    sock;                    // socket fd

    // internal state
    time_t last_time;               // time when the prefix was last generated
    char   linebuf[LOG_BUFSIZE];    // log line, including prefix and message
    size_t prefix_len;              // length of the prefix string
    char*  msg_start;               // pointer into linebuf_ after end of prefix

    // error reporting
    char*  err;                     // error string

} FastSyslogger;

FastSyslogger* FSL_alloc();
int FSL_init(FastSyslogger* logger, int proto, char* hostname, int port, int facility, int severity, char* sender, char* name);
int FSL_destroy(FastSyslogger* logger);

int FSL_set_receiver(FastSyslogger* logger, int proto, char* hostname, int port);
void FSL_set_priority(FastSyslogger* logger, int facility, int severity);
void FSL_set_sender(FastSyslogger* logger, char* sender);
void FSL_set_name(FastSyslogger* logger, char* name);
void FSL_set_pid(FastSyslogger* logger, int pid);

int FSL_send(FastSyslogger* logger, char* msg, int len, time_t t);

#endif
