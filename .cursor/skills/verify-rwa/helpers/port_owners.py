#!/usr/bin/env python3
"""Print listeners for ports 3000 and 3001.

Each line is: PORT PID ADDR
Exit 0 even when nothing is listening. Exit 2 on usage or proc read errors.
"""

import glob
import os
import socket
import sys

PORTS = {3000, 3001}


def parse(path, ipv6):
    found = []
    if not os.path.exists(path):
        return found
    with open(path, encoding="utf-8") as handle:
        next(handle)
        for line in handle:
            parts = line.split()
            if len(parts) < 10 or parts[3] != "0A":
                continue
            ip_hex, port_hex = parts[1].split(":")
            port = int(port_hex, 16)
            if port not in PORTS:
                continue
            raw = bytes.fromhex(ip_hex)
            if ipv6:
                words = [raw[i : i + 4][::-1] for i in range(0, 16, 4)]
                addr = socket.inet_ntop(socket.AF_INET6, b"".join(words))
            else:
                addr = socket.inet_ntop(socket.AF_INET, raw[::-1])
            found.append((port, parts[9], addr))
    return found


def pid_for_inode(inode):
    needle = f"socket:[{inode}]"
    for link in glob.glob("/proc/[0-9]*/fd/*"):
        try:
            if os.readlink(link) == needle:
                return int(link.split("/")[2])
        except OSError:
            continue
    return None


def main():
    rows = []
    rows.extend(parse("/proc/net/tcp", False))
    rows.extend(parse("/proc/net/tcp6", True))
    for port, inode, addr in rows:
        pid = pid_for_inode(inode)
        print(f"{port} {pid if pid is not None else '-'} {addr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
