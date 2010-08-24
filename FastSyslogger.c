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

static
void
update_prefix(FastSyslogger* logger, time_t t)
{
    logger->last_time_ = t;

    char timestr[30];
    strftime(timestr, 30, "%h %e %T", localtime(&t));

    logger->prefix_len_ = snprintf(logger->linebuf_, LOG_BUFSIZE,
        "<%d>%s %s %s[%d]: ",
        logger->priority_, timestr, logger->sender_, logger->name_, logger->pid_
    );

    // cache the location in linebuf where msg should be pasted in
    logger->msg_start_ = logger->linebuf_ + logger->prefix_len_;
}

FastSyslogger*
FastSyslogger_alloc()
{
    return malloc(sizeof(FastSyslogger));
}

FastSyslogger_init(
    FastSyslogger* logger, int proto, char* hostname, int port,
    int facility, int severity, char* sender, char* name)
{
    if (!logger)
        return -1;

    logger->pid_ = getpid();
    strncpy(logger->sender_, sender, sizeof(logger->sender_) - 1);
    strncpy(logger->name_, name, sizeof(logger->name_) - 1);
    logger->priority_ = (facility << 3) | severity;
    update_prefix(logger, time(0));

    return FastSyslogger_setReceiver(logger, proto, hostname, port);
}

int
FastSyslogger_destroy(FastSyslogger* logger)
{
    int ret = close(logger->sock_);
    free(logger);
    return ret;
}

void
FastSyslogger_setPriority(FastSyslogger* logger, int facility, int severity)
{
    logger->priority_ = (facility << 3) | severity;
    update_prefix(logger, time(0));
}

void
FastSyslogger_setSender(FastSyslogger* logger, char* sender)
{
    strncpy(logger->sender_, sender, sizeof(logger->sender_) - 1);
    update_prefix(logger, time(0));
}

void
FastSyslogger_setName(FastSyslogger* logger, char* name)
{
    strncpy(logger->name_, name, sizeof(logger->name_) - 1);
    update_prefix(logger, time(0));
}

void
FastSyslogger_setPid(FastSyslogger* logger, int pid)
{
    logger->pid_ = pid;
    update_prefix(logger, time(0));
}

int
FastSyslogger_setReceiver(FastSyslogger* logger, int proto, char* hostname, int port)
{
    const struct sockaddr* p_address;
    int address_len;

    // set up a socket, letting kernel assign local port
    if (proto == 0 || proto == 1) {
        // resolve the remote host
        struct hostent* host = gethostbyname(hostname);
        if (!host || !host->h_addr_list || !host->h_addr_list[0]) {
            logger->err_ = "resolve failure";
            return -1;
        }

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
            logger->sock_ = socket(AF_INET, SOCK_DGRAM, 0);

            // make the socket non-blocking
            int flags = fcntl(logger->sock_, F_GETFL, 0);
            fcntl(logger->sock_, F_SETFL, flags | O_NONBLOCK);
            flags = fcntl(logger->sock_, F_GETFL, 0);
            if (!(flags & O_NONBLOCK)) {
                logger->err_ = "nonblock failure";
                return -1;
            }
        }
        else if (proto == 1) {
            // LOG_TCP from FastSyslogger.pm
            logger->sock_ = socket(AF_INET, SOCK_STREAM, 0);
        }
    }
    else if (proto == 2) {
        // LOG_UNIX from FastSyslogger.pm

        // create the log device's address
        struct sockaddr_un raddress;
        raddress.sun_family = AF_UNIX;
        strcpy(raddress.sun_path, hostname);
        p_address = (const struct sockaddr*) &raddress;
        address_len = sizeof(raddress);

        // construct socket
        logger->sock_ = socket(AF_UNIX, SOCK_STREAM, 0);
    }
    else {
        logger->err_ = "bad protocol";
        return -1;
    }

    if (logger->sock_ < 0) {
        logger->err_ = strerror(errno);
        return -1;
    }

    // close the socket after exec to match normal Perl behavior for sockets
    fcntl(logger->sock_, F_SETFD, FD_CLOEXEC);

    // connect the socket
    if (connect(logger->sock_, p_address, address_len) != 0) {
        // some servers (rsyslog) may use SOCK_DGRAM for unix domain sockets
        if (proto == 2 && errno == EPROTOTYPE) {
            logger->sock_ = socket(AF_UNIX, SOCK_DGRAM, 0);
            if (connect(logger->sock_, p_address, address_len) != 0) {
                logger->err_ = strerror(errno);
                return -1;
            }
        }
        else {
            logger->err_ = strerror(errno);
            return -1;
        }
    }

    return 0;
}

int
FastSyslogger_send(FastSyslogger* logger, char* msg, int len, time_t t)
{
    // update the prefix if seconds have rolled over
    if (t != logger->last_time_)
        update_prefix(logger, t);

    // paste the message into linebuf just past where the prefix was placed
    int msg_len = len < LOG_BUFSIZE - logger->prefix_len_ ? len : LOG_BUFSIZE - logger->prefix_len_;
    strncpy(logger->msg_start_, msg, msg_len);

    int ret = send(logger->sock_, logger->linebuf_, logger->prefix_len_ + msg_len, MSG_DONTWAIT);
    if (ret < 0)
        logger->err_ = strerror(errno);
    return ret;
}
