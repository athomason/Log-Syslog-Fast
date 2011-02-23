#include "LogSyslogFast.h"

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

static
void
update_prefix(LogSyslogFast* logger, time_t t)
{
    logger->last_time = t;

    char timestr[30];
    strftime(timestr, 30, "%h %e %T", localtime(&t));

    logger->prefix_len = snprintf(logger->linebuf, LOG_BUFSIZE,
        "<%d>%s %s %s[%d]: ",
        logger->priority, timestr, logger->sender, logger->name, logger->pid
    );
    if (logger->prefix_len > LOG_BUFSIZE - 1)
        logger->prefix_len = LOG_BUFSIZE - 1;

    /* cache the location in linebuf where msg should be pasted in */
    logger->msg_start = logger->linebuf + logger->prefix_len;
}

LogSyslogFast*
LSF_alloc()
{
    return malloc(sizeof(LogSyslogFast));
}

int
LSF_init(
    LogSyslogFast* logger, int proto, char* hostname, int port,
    int facility, int severity, char* sender, char* name)
{
    if (!logger)
        return -1;

    logger->pid = getpid();

    LSF_set_sender(logger, sender);
    LSF_set_name(logger, name);

    logger->priority = (facility << 3) | severity;
    update_prefix(logger, time(0));

    return LSF_set_receiver(logger, proto, hostname, port);
}

int
LSF_destroy(LogSyslogFast* logger)
{
    int ret = close(logger->sock);
    if (ret)
        logger->err = strerror(errno);
    free(logger);
    return ret;
}

void
LSF_set_priority(LogSyslogFast* logger, int facility, int severity)
{
    logger->priority = (facility << 3) | severity;
    update_prefix(logger, time(0));
}

void
LSF_set_facility(LogSyslogFast* logger, int facility)
{
    LSF_set_priority(logger, facility, LSF_get_severity(logger));
}

void
LSF_set_severity(LogSyslogFast* logger, int severity)
{
    LSF_set_priority(logger, LSF_get_facility(logger), severity);
}

void
LSF_set_sender(LogSyslogFast* logger, char* sender)
{
    memset(logger->sender, '\0', sizeof(logger->sender));
    strncpy(logger->sender, sender, sizeof(logger->sender) - 1);
    update_prefix(logger, time(0));
}

void
LSF_set_name(LogSyslogFast* logger, char* name)
{
    memset(logger->name, '\0', sizeof(logger->name));
    strncpy(logger->name, name, sizeof(logger->name) - 1);
    update_prefix(logger, time(0));
}

void
LSF_set_pid(LogSyslogFast* logger, int pid)
{
    logger->pid = pid;
    update_prefix(logger, time(0));
}

#ifdef AF_INET6
#define clean_return(x) if (results) freeaddrinfo(results); return x;
#else
#define clean_return(x) return x;
#endif

/* must match constants in LogSyslogFast.pm */
#define LOG_UDP  0
#define LOG_TCP  1
#define LOG_UNIX 2

int
LSF_set_receiver(LogSyslogFast* logger, int proto, char* hostname, int port)
{
    const struct sockaddr* p_address;
    int address_len;
#ifdef AF_INET6
    struct addrinfo* results = NULL;
#endif

    /* set up a socket, letting kernel assign local port */
    if (proto == LOG_UDP || proto == LOG_TCP) {

#ifdef AF_INET6

/* http://www.mail-archive.com/bug-gnulib@gnu.org/msg17067.html */
#ifndef AI_ADDRCONFIG
#define AI_ADDRCONFIG 0
#endif

        struct addrinfo *rp;
        struct addrinfo hints;
        char portstr[32];
        int r;

        snprintf(portstr, sizeof(portstr), "%d", port);
        memset(&hints, 0, sizeof(hints));
        hints.ai_flags = AI_ADDRCONFIG | AI_NUMERICSERV;
        hints.ai_family = AF_UNSPEC;
        if (proto == LOG_TCP) {
            hints.ai_socktype = SOCK_STREAM;
        } else {
            hints.ai_socktype = SOCK_DGRAM;
        }
        hints.ai_protocol = 0;
        hints.ai_addrlen = 0;
        hints.ai_addr = NULL;
        hints.ai_canonname = NULL;
        hints.ai_next = NULL;

        r = getaddrinfo(hostname, portstr, &hints, &results);
        if (r < 0 || !results) {
            logger->err = "getaddrinfo failure";
            return -1;
        }
        for (rp = results; rp != NULL; rp = rp->ai_next) {
            logger->sock = socket(rp->ai_family, rp->ai_socktype, 0);
            if (logger->sock == -1) {
                r = errno;
                continue;
            }
            p_address = rp->ai_addr;
            address_len = rp->ai_addrlen;
            break;
        }
        if (logger->sock == -1) {
            logger->err = "socket failure";
            clean_return(-1);
        }

#else /* !AF_INET6 */

        /* resolve the remote host */
        struct hostent* host = gethostbyname(hostname);
        if (!host || !host->h_addr_list || !host->h_addr_list[0]) {
            logger->err = "resolve failure";
            return -1;
        }

        /* create the remote host's address */
        struct sockaddr_in raddress;
        raddress.sin_family = AF_INET;
        memcpy(&raddress.sin_addr, host->h_addr_list[0], sizeof(raddress.sin_addr));
        raddress.sin_port = htons(port);
        p_address = (const struct sockaddr*) &raddress;
        address_len = sizeof(raddress);

        /* construct socket */
        if (proto == LOG_UDP) {
            logger->sock = socket(AF_INET, SOCK_DGRAM, 0);

            /* make the socket non-blocking */
            int flags = fcntl(logger->sock, F_GETFL, 0);
            fcntl(logger->sock, F_SETFL, flags | O_NONBLOCK);
            flags = fcntl(logger->sock, F_GETFL, 0);
            if (!(flags & O_NONBLOCK)) {
                logger->err = "nonblock failure";
                return -1;
            }
        }
        else if (proto == LOG_TCP) {
            logger->sock = socket(AF_INET, SOCK_STREAM, 0);
        }

#endif /* AF_INET6 */
    }
    else if (proto == LOG_UNIX) {

        /* create the log device's address */
        struct sockaddr_un raddress;
        raddress.sun_family = AF_UNIX;
        strncpy(raddress.sun_path, hostname, sizeof(raddress.sun_path) - 1);
        p_address = (const struct sockaddr*) &raddress;
        address_len = sizeof(raddress);

        /* construct socket */
        logger->sock = socket(AF_UNIX, SOCK_STREAM, 0);
    }
    else {
        logger->err = "bad protocol";
        return -1;
    }

    if (logger->sock < 0) {
        logger->err = strerror(errno);
        clean_return(-1);
    }

    /* close the socket after exec to match normal Perl behavior for sockets */
    fcntl(logger->sock, F_SETFD, FD_CLOEXEC);

    /* connect the socket */
    if (connect(logger->sock, p_address, address_len) != 0) {
        /* some servers (rsyslog) may use SOCK_DGRAM for unix domain sockets */
        if (proto == LOG_UNIX && errno == EPROTOTYPE) {
            logger->sock = socket(AF_UNIX, SOCK_DGRAM, 0);
            if (connect(logger->sock, p_address, address_len) != 0) {
                logger->err = strerror(errno);
                clean_return(-1);
            }
        }
        else {
            logger->err = strerror(errno);
            clean_return(-1);
        }
    }

    clean_return(0);
}

int
LSF_send(LogSyslogFast* logger, char* msg, int len, time_t t)
{
    /* update the prefix if seconds have rolled over */
    if (t != logger->last_time)
        update_prefix(logger, t);

    /* paste the message into linebuf just past where the prefix was placed */
    int msg_len = len < LOG_BUFSIZE - logger->prefix_len ? len : LOG_BUFSIZE - logger->prefix_len;
    strncpy(logger->msg_start, msg, msg_len);
    *(logger->msg_start + msg_len) = '\0';

    int ret = send(logger->sock, logger->linebuf, logger->prefix_len + msg_len, 0);
    if (ret < 0)
        logger->err = strerror(errno);
    return ret;
}

int
LSF_get_priority(LogSyslogFast* logger)
{
    return logger->priority;
}

int
LSF_get_facility(LogSyslogFast* logger)
{
    return logger->priority >> 3;
}

int
LSF_get_severity(LogSyslogFast* logger)
{
    return logger->priority & 7;
}

char*
LSF_get_sender(LogSyslogFast* logger)
{
    return logger->sender;
}

char*
LSF_get_name(LogSyslogFast* logger)
{
    return logger->name;
}

int
LSF_get_pid(LogSyslogFast* logger)
{
    return logger->pid;
}
