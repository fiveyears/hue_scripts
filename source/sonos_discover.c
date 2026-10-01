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
    struct sockaddr_in dest_addr;
    char msg[] =
        "M-SEARCH * HTTP/1.1\r\n"
        "HOST: 239.255.255.250:1900\r\n"
        "MAN: \"ssdp:discover\"\r\n"
        "MX: 1\r\n"
        "ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n"
        "\r\n";

    sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    /* Set multicast TTL (optional, but like the Python example) */
    int ttl = 2;
    if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl)) < 0) {
        perror("setsockopt(IP_MULTICAST_TTL)");
        /* Not fatal, continue */
    }

    /* Set receive timeout (2 seconds) */
    struct timeval tv;
    tv.tv_sec = 2;
    tv.tv_usec = 0;
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        perror("setsockopt(SO_RCVTIMEO)");
        /* Not fatal, continue */
    }

    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(SSDP_PORT);
    dest_addr.sin_addr.s_addr = inet_addr(SSDP_ADDR);

    ssize_t sent = sendto(sock, msg, strlen(msg), 0,
                          (struct sockaddr *)&dest_addr, sizeof(dest_addr));
    if (sent < 0) {
        perror("sendto");
        close(sock);
        return 1;
    }

    printf("Searching for Sonos devices...\n");

    while (1) {
        char buf[2048];
        struct sockaddr_in src_addr;
        socklen_t src_len = sizeof(src_addr);
        ssize_t len = recvfrom(sock, buf, sizeof(buf) - 1, 0,
                               (struct sockaddr *)&src_addr, &src_len);
        if (len < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                /* timeout */
                printf("Done (timeout).\n");
                break;
            } else {
                perror("recvfrom");
                break;
            }
        }

        buf[len] = '\0';  /* make it a C-string */

        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &src_addr.sin_addr, ip, sizeof(ip));
        printf("\nResponse from %s:%d\n", ip, ntohs(src_addr.sin_port));
        printf("%s\n", buf);
    }

    close(sock);
    return 0;
}