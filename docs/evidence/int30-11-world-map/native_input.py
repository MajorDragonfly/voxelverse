#!/usr/bin/env python3
"""Actual X11/XTest events on the review's private virtual display."""
import ctypes as C
import sys
x = C.CDLL('libX11.so.6')
t = C.CDLL('libXtst.so.6')
x.XOpenDisplay.argtypes=[C.c_char_p]; x.XOpenDisplay.restype=C.c_void_p
x.XStringToKeysym.argtypes=[C.c_char_p]; x.XStringToKeysym.restype=C.c_ulong
x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong]; x.XKeysymToKeycode.restype=C.c_uint
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
x.XSync.argtypes=[C.c_void_p,C.c_int]
x.XCloseDisplay.argtypes=[C.c_void_p]
t.XTestFakeMotionEvent.argtypes=[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]
t.XTestFakeButtonEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
t.XTestFakeKeyEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
d=x.XOpenDisplay(None)
if not d:raise SystemExit('No private X11 display')
try:
    op=sys.argv[1]
    if op=='move':t.XTestFakeMotionEvent(d,-1,int(sys.argv[2]),int(sys.argv[3]),0)
    elif op=='button':t.XTestFakeButtonEvent(d,int(sys.argv[2]),int(sys.argv[3]),0)
    elif op=='key':
        code=x.XKeysymToKeycode(d,x.XStringToKeysym(sys.argv[2].encode()))
        if not code:raise SystemExit('Unknown X11 keysym '+sys.argv[2])
        t.XTestFakeKeyEvent(d,code,int(sys.argv[3]),0)
    elif op=='focus':x.XSetInputFocus(d,int(sys.argv[2]),2,0)
    else:raise SystemExit('Unknown operation')
    x.XSync(d,False)
finally:x.XCloseDisplay(d)
