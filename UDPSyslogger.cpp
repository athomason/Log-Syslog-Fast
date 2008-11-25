#include "UDPSyslogger.h"

#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

UDPSyslogger::UDPSyslogger(char* hostname, int port, int facility, int severity, char* sender, char* name) :
    pid_(getpid())
{
    setReceiver(hostname, port);
    setSenderWithoutUpdate(sender);
    setNameWithoutUpdate(name);
    setPriorityWithoutUpdate(facility, severity);
    updatePrefix();
}

UDPSyslogger::~UDPSyslogger()
{
    close(sock_);
}

void
UDPSyslogger::setReceiver(char* hostname, int port)
{
    // resolve the remote host
    struct hostent* host = gethostbyname(hostname);
    if (!host || !host->h_addr_list || !host->h_addr_list[0])
        throw "resolve failure";

    // set up a socket
    sock_ = socket(AF_INET, SOCK_DGRAM, 0); // let kernel assign local port
    if (sock_ < 0)
        throw "socket failure";

    // make the socket non-blocking
    int flags = fcntl(sock_, F_GETFL, 0);
    fcntl(sock_, F_SETFL, flags | O_NONBLOCK);
    flags = fcntl(sock_, F_GETFL, 0);
    if (!(flags & O_NONBLOCK))
        throw "nonblock failure";

    // create the remote host's address
    struct sockaddr_in raddress;
    raddress.sin_family = AF_INET;
    memcpy(&raddress.sin_addr, host->h_addr_list[0], sizeof(raddress.sin_addr));
    raddress.sin_port = htons(port);

    // set the destination address
    if (connect(sock_, (const struct sockaddr*) &raddress, sizeof raddress)) {
        throw "connect failure";
    }
}

void
UDPSyslogger::setPriorityWithoutUpdate(int facility, int severity)
{
    priority_ = (facility << 3) | severity;
}

void
UDPSyslogger::setSenderWithoutUpdate(char* sender)
{
    strncpy(sender_, sender, sizeof(sender_) - 1);
}

void
UDPSyslogger::setNameWithoutUpdate(char* name)
{
    strncpy(name_, name, sizeof(name_)   - 1);
}

void
UDPSyslogger::updatePrefix(time_t t) {
    last_time_ = t;

    char timestr[30];
    strftime(timestr, 30, "%h %e %T", localtime(&t));

    prefix_len_ = sprintf(linebuf_, "<%d>%s %s %s[%d]: ",
        priority_, timestr, sender_, name_, pid_
    );

    // cache the location in linebuf where msg should be pasted in
    msg_start_ = linebuf_ + prefix_len_;
}

static inline
int
min(int a, int b)
{
    return a < b ? a : b;
}

void
UDPSyslogger::send(char* msg, int len, time_t t)
{
    // update the prefix if seconds have rolled over
    if (t != last_time_)
        updatePrefix(t);

    // paste the message into linebuf just past where the prefix was placed
    int msg_len = min(len, LOG_BUFSIZE - prefix_len_);
    strncpy(msg_start_, msg, msg_len);

    ::send(sock_, linebuf_, prefix_len_ + msg_len, MSG_DONTWAIT);
}

/*
int
main()
{
    int i;
    UDPSyslogger* logger;
    try {
        logger = new UDPSyslogger("127.0.0.1", 514, 4, 6, "athomason-many", "proftest");
    }
    catch (const char* c) {
        perror(c);
        return 1;
    }
    char buf[20];
    for (i = 0; i < 10; i++) {
        int len = sprintf(buf, "testing %d\n", i);
        logger->send(buf, len, time(0));
    }
}
*/
