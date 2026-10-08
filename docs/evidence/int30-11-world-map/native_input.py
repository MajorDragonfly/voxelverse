#!/usr/bin/env python3
"""Actual X11/XTest events on the review's private virtual display."""
import ctypes as C
import sys
import time
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
    elif op=='tap':
        code=x.XKeysymToKeycode(d,x.XStringToKeysym(sys.argv[2].encode()))
        if not code:raise SystemExit('Unknown X11 keysym '+sys.argv[2])
        control=x.XKeysymToKeycode(d,x.XStringToKeysym(b'Control_L')) if len(sys.argv)>3 and sys.argv[3]=='ctrl' else 0
        if control:t.XTestFakeKeyEvent(d,control,1,0)
        t.XTestFakeKeyEvent(d,code,1,0);x.XSync(d,False)
        # Finish the physical pulse independently of Godot's frame rate.
        time.sleep(0.05)
        t.XTestFakeKeyEvent(d,code,0,0)
        if control:t.XTestFakeKeyEvent(d,control,0,0)
    elif op=='focus':x.XSetInputFocus(d,int(sys.argv[2]),2,0)
    else:raise SystemExit('Unknown operation')
    x.XSync(d,False)
finally:x.XCloseDisplay(d)
