#ifndef __LOGSYSLOGFAST_H__
#define __LOGSYSLOGFAST_H__

#include <time.h>

#define LOG_BUFSIZE 16384

typedef struct {

    /* configuration */
    int    priority;                /* RFC3164/4.1.1 PRI Part */
    char   sender[LOG_BUFSIZE];     /* sender hostname */
    char   name[LOG_BUFSIZE];       /* sending program name */
    int    pid;                     /* sending program pid */

    /* resource handles */
    int    sock;                    /* socket fd */

    /* internal state */
    time_t last_time;               /* time when the prefix was last generated */
    char   linebuf[LOG_BUFSIZE];    /* log line, including prefix and message */
    size_t prefix_len;              /* length of the prefix string */
    char*  msg_start;               /* pointer into linebuf_ after end of prefix */

    /* error reporting */
    char*  err;                     /* error string */

} LogSyslogFast;

LogSyslogFast* LSF_alloc();
int LSF_init(LogSyslogFast* logger, int proto, char* hostname, int port, int facility, int severity, char* sender, char* name);
int LSF_destroy(LogSyslogFast* logger);

int LSF_set_receiver(LogSyslogFast* logger, int proto, char* hostname, int port);

void LSF_set_priority(LogSyslogFast* logger, int facility, int severity);
void LSF_set_facility(LogSyslogFast* logger, int facility);
void LSF_set_severity(LogSyslogFast* logger, int severity);
void LSF_set_sender(LogSyslogFast* logger, char* sender);
void LSF_set_name(LogSyslogFast* logger, char* name);
void LSF_set_pid(LogSyslogFast* logger, int pid);

int LSF_get_priority(LogSyslogFast* logger);
int LSF_get_facility(LogSyslogFast* logger);
int LSF_get_severity(LogSyslogFast* logger);
char* LSF_get_sender(LogSyslogFast* logger);
char* LSF_get_name(LogSyslogFast* logger);
int LSF_get_pid(LogSyslogFast* logger);

int LSF_send(LogSyslogFast* logger, char* msg, int len, time_t t);

#endif
