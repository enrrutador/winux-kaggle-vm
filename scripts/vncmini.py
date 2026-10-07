#!/usr/bin/env python3
"""Mini VNC/RFB 3.8 client (stdlib+PIL): screenshots + absolute clicks + keys."""
import socket
import struct
import sys
import time

from PIL import Image

HOST, PORT = "127.0.0.1", 5900


def _recvn(s, n):
    buf = b""
    while len(buf) < n:
        c = s.recv(n - len(buf))
        if not c:
            raise ConnectionError("EOF")
        buf += c
    return buf


class VNC:
    def __init__(self, host=HOST, port=PORT):
        self.s = socket.create_connection((host, port), timeout=15)
        _recvn(self.s, 12)  # server version
        self.s.sendall(b"RFB 003.008\n")
        nsec = _recvn(self.s, 1)[0]
        sectypes = _recvn(self.s, nsec)
        if 1 not in sectypes:
            raise RuntimeError("sin auth None")
        self.s.sendall(b"\x01")
        if struct.unpack(">I", _recvn(self.s, 4))[0] != 0:
            raise RuntimeError("SecurityResult != OK")
        self.s.sendall(b"\x01")  # shared
        si = _recvn(self.s, 24)
        self.w, self.h = struct.unpack(">HH", si[:4])
        self.bpp = si[4]
        namelen = struct.unpack(">I", si[20:24])[0]
        _recvn(self.s, namelen)
        self.s.sendall(struct.pack(">BBHI", 2, 0, 1, 0))  # pedir Raw
        time.sleep(0.2)

    def pointer(self, x, y, mask=0):
        self.s.sendall(struct.pack(">BBHH", 5, mask, x, y))
        time.sleep(0.15)

    def click(self, x, y, double=False):
        if double:
            for _ in range(2):
                self.s.sendall(struct.pack(">BBHH", 5, 1, x, y))
                time.sleep(0.06)
                self.s.sendall(struct.pack(">BBHH", 5, 0, x, y))
                time.sleep(0.1)
            time.sleep(0.15)
            return
        self.pointer(x, y, 0)
        self.pointer(x, y, 1)
        self.pointer(x, y, 0)

    def key(self, keysym):
        self.s.sendall(struct.pack(">BBHI", 4, 1, 0, keysym))
        time.sleep(0.08)
        self.s.sendall(struct.pack(">BBHI", 4, 0, 0, keysym))
        time.sleep(0.08)

    def type_text(self, text):
        for ch in text:
            self.key(ord(ch))

    def shot(self, path):
        self.s.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, self.w, self.h))
        img = Image.new("RGB", (self.w, self.h))
        self.s.settimeout(30)
        nrect = struct.unpack(">H", _recvn(self.s, 4)[2:4])[0]
        for _ in range(nrect):
            x, y, w, h, enc = struct.unpack(">HHHHI", _recvn(self.s, 12))
            if enc != 0:
                raise RuntimeError("solo Raw")
            px = _recvn(self.s, w * h * (self.bpp // 8))
            tile = Image.frombytes(
                "RGB", (w, h), px, "raw",
                "BGRX" if self.bpp == 32 else "BGR",
            )
            img.paste(tile, (x, y))
        img.save(path)
        return path

    def close(self):
        self.s.close()


def main():
    cmd = sys.argv[1]
    v = VNC()
    try:
        if cmd == "shot":
            print(v.shot(sys.argv[2] if len(sys.argv) > 2 else "/tmp/shot.png"),
                  f"{v.w}x{v.h}")
        elif cmd == "click":
            x, y = int(sys.argv[2]), int(sys.argv[3])
            v.click(x, y, double=("--double" in sys.argv))
            print(f"click {x},{y}")
        elif cmd == "key":
            v.key(int(sys.argv[2], 0))
            print("key ok")
        elif cmd == "keydown":
            v.s.sendall(struct.pack(">BBHI", 4, 1, 0, int(sys.argv[2], 0)))
            print("keydown ok")
        elif cmd == "keyup":
            v.s.sendall(struct.pack(">BBHI", 4, 0, 0, int(sys.argv[2], 0)))
            print("keyup ok")
        elif cmd == "selectall":
            v.s.sendall(struct.pack(">BBHI", 4, 1, 0, 0xFFE3))
            time.sleep(0.1)
            v.key(ord("a"))
            v.s.sendall(struct.pack(">BBHI", 4, 0, 0, 0xFFE3))
            time.sleep(0.2)
            print("selectall ok")
        elif cmd == "type":
            v.type_text(sys.argv[2])
            print("type ok")
    finally:
        v.close()


if __name__ == "__main__":
    main()
