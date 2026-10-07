#!/usr/bin/env python3
"""Tipeo por monitor QEMU (bypassa el mapeo roto de VNC). Uso: monkey.py 'texto' [ret]"""
import socket
import sys
import time

SYM = {
    " ": "spc", ".": "dot", "/": "slash", "-": "minus", "_": "shift-minus",
    "=": "equal", "+": "shift-equal", ":": "shift-semicolon", ";": "semicolon",
    ",": "comma", "<": "shift-comma", ">": "shift-dot",
    "'": "apostrophe", '"': "shift-apostrophe",
    "[": "bracket_left", "]": "bracket_right",
    "(": "shift-9", ")": "shift-0",
    "!": "shift-1", "?": "shift-slash", "*": "shift-8",
    "&": "shift-7", "|": "shift-backslash", "\\": "backslash",
    "$": "shift-4", "#": "shift-3", "@": "shift-2", "%": "shift-5",
    "^": "shift-6", "~": "shift-backquote", "`": "backquote",
}


def key_for(ch):
    if "a" <= ch <= "z" or "0" <= ch <= "9":
        return ch
    if "A" <= ch <= "Z":
        return "shift-" + ch.lower()
    return SYM[ch]


def main():
    text = sys.argv[1]
    do_ret = len(sys.argv) > 2 and sys.argv[2] == "ret"
    keys = [key_for(c) for c in text]
    if do_ret:
        keys.append("ret")
    s = socket.socket(socket.AF_UNIX)
    s.connect("/kaggle/working/vmdata/winux-mon.sock")
    s.settimeout(10)
    try:
        s.recv(4096)
    except Exception:
        pass
    for k in keys:
        s.sendall(("sendkey %s\n" % k).encode())
        time.sleep(0.45)
        try:
            s.recv(300)
        except Exception:
            pass
    s.close()
    print("tipeado %d teclas" % len(keys))


if __name__ == "__main__":
    main()
