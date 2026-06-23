#!/usr/bin/env python3
"""Persistent serial-console driver for the Gentoo guest.

Holds the single connection to QEMU's serial unix socket, appends all
guest output to serial.log, and forwards anything written to the FIFO
(vmctl.cmd) to the guest. Run in background:

    python3 vmctl.py &

Send a line to the guest:
    printf 'whoami\n' > qemu-run/vmctl.cmd
Send a raw control char (e.g. Ctrl-C = \x03) via the same FIFO.
Read output with: tail -n 40 qemu-run/serial.log
"""
import os, socket, threading, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
SOCK = os.path.join(HERE, "serial.sock")
LOG = os.path.join(HERE, "serial.log")
FIFO = os.path.join(HERE, "vmctl.cmd")

def main():
    # wait for the serial socket to exist
    for _ in range(120):
        if os.path.exists(SOCK):
            break
        time.sleep(0.5)
    else:
        print("serial.sock never appeared", file=sys.stderr); sys.exit(1)

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)

    if os.path.exists(FIFO):
        os.remove(FIFO)
    os.mkfifo(FIFO)

    logf = open(LOG, "ab", buffering=0)

    def reader():
        while True:
            data = s.recv(4096)
            if not data:
                logf.write(b"\n[vmctl] serial closed\n"); return
            logf.write(data)
    threading.Thread(target=reader, daemon=True).start()

    # forward FIFO -> serial, line by line, reopening the fifo after each EOF
    while True:
        with open(FIFO, "rb") as f:
            data = f.read()
        if data:
            s.sendall(data)

if __name__ == "__main__":
    main()
