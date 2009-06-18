#ifndef __FASTSYSLOG_H__
#define __FASTSYSLOG_H__

#include <time.h>

#define LOG_BUFSIZE 16384

class FastSyslogger {
public:

    FastSyslogger(int proto, char* hostname, int port, int facility, int severity, char* sender, char* name);
    ~FastSyslogger();

    unsigned int send(char* msg, int len, time_t t);

    void setReceiver(int proto, char* hostname, int port);

    void setPriority(int facility, int severity) {
        setPriorityWithoutUpdate(facility, severity);
        updatePrefix();
    }

    void setSender(char* sender) {
        setSenderWithoutUpdate(sender);
        updatePrefix();
    }

    void setName(char* name) {
        setNameWithoutUpdate(name);
        updatePrefix();
    }

    void setPid(int pid) {
        setPidWithoutUpdate(pid);
        updatePrefix();
    }

protected:

    void setPriorityWithoutUpdate(int facility, int severity);
    void setSenderWithoutUpdate(char* sender);
    void setNameWithoutUpdate(char* name);
    void setPidWithoutUpdate(int pid);

    void updatePrefix(time_t t = time(NULL));

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

};

#endif
