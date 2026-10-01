#!/usr/bin/env python
# import socket

# sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
# sock.bind(("", 1900))

# print("Listening for SSDP NOTIFY packets...")

# while True:
#     data, addr = sock.recvfrom(65507)
#     if b"Sonos" in data:
#         print(f"\nFrom {addr}:")
#         print(data.decode(errors="ignore"))


import socket
import time

# SSDP multicast target
MCAST_GRP = "239.255.255.250"
MCAST_PORT = 1900

# Standard UPnP discovery request
msg = \
    'M-SEARCH * HTTP/1.1\r\n' \
    f'HOST: {MCAST_GRP}:{MCAST_PORT}\r\n' \
    'MAN: "ssdp:discover"\r\n' \
    'MX: 1\r\n' \
    'ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n' \
    '\r\n'

# Create UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
sock.settimeout(2)

# Send discovery message
sock.sendto(msg.encode(), (MCAST_GRP, MCAST_PORT))

print("Searching for Sonos devices...")

# Receive responses
try:
    while True:
        data, addr = sock.recvfrom(65507)
        print(f"\nResponse from {addr}:")
        print(data.decode(errors="ignore"))
except socket.timeout:
    print("\nDone.")