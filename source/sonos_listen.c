#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define SSDP_ADDR "239.255.255.250"
#define SSDP_PORT 1900

int main(void) {
    int sock;
    struct sockaddr_in local_addr;
    struct ip_mreq mreq;

    sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    /* Allow multiple listeners on the same port (optional but common) */
    int reuse = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) < 0) {
        perror("setsockopt(SO_REUSEADDR)");
        /* Not fatal, continue */
    }

    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(SSDP_PORT);
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(sock, (struct sockaddr *)&local_addr, sizeof(local_addr)) < 0) {
        perror("bind");
        close(sock);
        return 1;
    }

    /* Join the SSDP multicast group */
    mreq.imr_multiaddr.s_addr = inet_addr(SSDP_ADDR);
    mreq.imr_interface.s_addr = htonl(INADDR_ANY);
    if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                   &mreq, sizeof(mreq)) < 0) {
        perror("setsockopt(IP_ADD_MEMBERSHIP)");
        close(sock);
        return 1;
    }

    printf("Listening for SSDP packets on %s:%d ...\n", SSDP_ADDR, SSDP_PORT);

    while (1) {
        char buf[2048];
        struct sockaddr_in src_addr;
        socklen_t src_len = sizeof(src_addr);
        ssize_t len = recvfrom(sock, buf, sizeof(buf) - 1, 0,
                               (struct sockaddr *)&src_addr, &src_len);
        if (len < 0) {
            perror("recvfrom");
            break;
        }

        buf[len] = '\0';

        /* Only print Sonos-related packets (like the Python example) */
        if (strstr(buf, "Sonos") != NULL) {
            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &src_addr.sin_addr, ip, sizeof(ip));
            printf("\nPacket from %s:%d\n", ip, ntohs(src_addr.sin_port));
            printf("%s\n", buf);
        }
    }

    close(sock);
    return 0;
}