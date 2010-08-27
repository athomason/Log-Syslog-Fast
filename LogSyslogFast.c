#include "LogSyslogFast.h"

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <time.h>
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
    strncpy(logger->sender, sender, sizeof(logger->sender) - 1);
    strncpy(logger->name, name, sizeof(logger->name) - 1);
    logger->priority = (facility << 3) | severity;
    update_prefix(logger, time(0));

    return LSF_set_receiver(logger, proto, hostname, port);
}

int
LSF_destroy(LogSyslogFast* logger)
{
    int ret = close(logger->sock);
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
LSF_set_sender(LogSyslogFast* logger, char* sender)
{
    strncpy(logger->sender, sender, sizeof(logger->sender) - 1);
    update_prefix(logger, time(0));
}

void
LSF_set_name(LogSyslogFast* logger, char* name)
{
    strncpy(logger->name, name, sizeof(logger->name) - 1);
    update_prefix(logger, time(0));
}

void
LSF_set_pid(LogSyslogFast* logger, int pid)
{
    logger->pid = pid;
    update_prefix(logger, time(0));
}

int
LSF_set_receiver(LogSyslogFast* logger, int proto, char* hostname, int port)
{
    const struct sockaddr* p_address;
    int address_len;

    /* set up a socket, letting kernel assign local port */
    if (proto == 0 || proto == 1) {
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
        if (proto == 0) {
            /* LOG_UDP from LogSyslogFast.pm */
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
        else if (proto == 1) {
            /* LOG_TCP from LogSyslogFast.pm */
            logger->sock = socket(AF_INET, SOCK_STREAM, 0);
        }
    }
    else if (proto == 2) {
        /* LOG_UNIX from LogSyslogFast.pm */

        /* create the log device's address */
        struct sockaddr_un raddress;
        raddress.sun_family = AF_UNIX;
        strcpy(raddress.sun_path, hostname);
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
        return -1;
    }

    /* close the socket after exec to match normal Perl behavior for sockets */
    fcntl(logger->sock, F_SETFD, FD_CLOEXEC);

    /* connect the socket */
    if (connect(logger->sock, p_address, address_len) != 0) {
        /* some servers (rsyslog) may use SOCK_DGRAM for unix domain sockets */
        if (proto == 2 && errno == EPROTOTYPE) {
            logger->sock = socket(AF_UNIX, SOCK_DGRAM, 0);
            if (connect(logger->sock, p_address, address_len) != 0) {
                logger->err = strerror(errno);
                return -1;
            }
        }
        else {
            logger->err = strerror(errno);
            return -1;
        }
    }

    return 0;
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

    int ret = send(logger->sock, logger->linebuf, logger->prefix_len + msg_len, MSG_DONTWAIT);
    if (ret < 0)
        logger->err = strerror(errno);
    return ret;
}
