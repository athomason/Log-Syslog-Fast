#include "FastSyslogger.h"

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

FastSyslogger::FastSyslogger(int proto, char* hostname, int port, int facility, int severity, char* sender, char* name) :
    pid_(getpid())
{
    setReceiver(proto, hostname, port);
    setSenderWithoutUpdate(sender);
    setNameWithoutUpdate(name);
    setPriorityWithoutUpdate(facility, severity);
    updatePrefix();
}

FastSyslogger::~FastSyslogger()
{
    close(sock_);
}

void
FastSyslogger::setReceiver(int proto, char* hostname, int port)
{
    const struct sockaddr* p_address;
    int address_len;

    // set up a socket, letting kernel assign local port
    if (proto == 0 || proto == 1) {
        // resolve the remote host
        struct hostent* host = gethostbyname(hostname);
        if (!host || !host->h_addr_list || !host->h_addr_list[0])
            throw "resolve failure";

        // create the remote host's address
        struct sockaddr_in raddress;
        raddress.sin_family = AF_INET;
        memcpy(&raddress.sin_addr, host->h_addr_list[0], sizeof(raddress.sin_addr));
        raddress.sin_port = htons(port);
        p_address = (const struct sockaddr*) &raddress;
        address_len = sizeof(raddress);

        // construct socket
        if (proto == 0) {
            // LOG_UDP from FastSyslogger.pm
            sock_ = socket(AF_INET, SOCK_DGRAM, 0);

            // make the socket non-blocking
            int flags = fcntl(sock_, F_GETFL, 0);
            fcntl(sock_, F_SETFL, flags | O_NONBLOCK);
            flags = fcntl(sock_, F_GETFL, 0);
            if (!(flags & O_NONBLOCK))
                throw "nonblock failure";
        }
        else if (proto == 1) {
            // LOG_TCP from FastSyslogger.pm
            sock_ = socket(AF_INET, SOCK_STREAM, 0);
        }
    }
    else if (proto == 2) {
        // LOG_UNIX from FastSyslogger.pm

        // create the log device's address
        struct sockaddr_un raddress;
        raddress.sun_family = AF_UNIX;
        strcpy(raddress.sun_path, hostname);
        p_address = (const struct sockaddr*) &raddress;
        address_len = strlen(raddress.sun_path) + sizeof(raddress.sun_family);

        // construct socket
        sock_ = socket(AF_UNIX, SOCK_STREAM, 0);
    }
    else
        throw "bad protocol";

    if (sock_ < 0)
        throw "socket failure";

    // close the socket after exec to match normal Perl behavior for sockets
    fcntl(sock_, F_SETFD, FD_CLOEXEC);

    // connect the socket
    if (connect(sock_, p_address, address_len) != 0)
        throw "connect failure";
}

void
FastSyslogger::setPriorityWithoutUpdate(int facility, int severity)
{
    priority_ = (facility << 3) | severity;
}

void
FastSyslogger::setSenderWithoutUpdate(char* sender)
{
    strncpy(sender_, sender, sizeof(sender_) - 1);
}

void
FastSyslogger::setNameWithoutUpdate(char* name)
{
    strncpy(name_, name, sizeof(name_)   - 1);
}

void
FastSyslogger::setPidWithoutUpdate(int pid)
{
    pid_ = pid;
}

void
FastSyslogger::updatePrefix(time_t t) {
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

int
FastSyslogger::send(char* msg, int len, time_t t)
{
    // update the prefix if seconds have rolled over
    if (t != last_time_)
        updatePrefix(t);

    // paste the message into linebuf just past where the prefix was placed
    int msg_len = min(len, LOG_BUFSIZE - prefix_len_);
    strncpy(msg_start_, msg, msg_len);

    int ret = ::send(sock_, linebuf_, prefix_len_ + msg_len, MSG_DONTWAIT);

    if (ret < 0)
        throw "send failed";

    return ret;
}
