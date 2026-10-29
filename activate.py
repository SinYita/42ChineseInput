#!/usr/bin/env python3
"""Activate rootless ibus-libpinyin in the current Ubuntu GNOME session."""

import os
import subprocess
import time

uid = os.getuid()
home = os.path.expanduser("~")
ibus_root = os.path.join(home, ".ibus")
symlink_base = f"/tmp/i{uid}"

if os.path.isdir(ibus_root):
    try:
        if os.path.islink(symlink_base) or os.path.exists(symlink_base):
            os.unlink(symlink_base)
        os.symlink(ibus_root, symlink_base)
    except OSError:
        pass

os.environ.setdefault("DISPLAY", ":0")
os.environ.setdefault("DBUS_SESSION_BUS_ADDRESS", f"unix:path=/run/user/{uid}/bus")
os.environ.setdefault("XDG_RUNTIME_DIR", f"/run/user/{uid}")
comp_path = f"{ibus_root}/component:/usr/share/ibus/component"
os.environ["IBUS_COMPONENT_PATH"] = comp_path

subprocess.run(["ibus", "write-cache"], check=False)
subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
subprocess.run(
    ["systemctl", "--user", "restart", "org.freedesktop.IBus.session.GNOME.service"],
    check=False,
)

import gi

gi.require_version("IBus", "1.0")
from gi.repository import GLib, Gio, IBus

IBus.init()
bus = None
for _ in range(10):
    time.sleep(0.5)
    candidate = IBus.Bus.new()
    if candidate.is_connected():
        bus = candidate
        break

print("Connected to IBus:", bool(bus and bus.is_connected()))
if bus and bus.is_connected():
    engines = bus.list_engines()
    zh_engines = [
        e.get_name()
        for e in engines
        if "zh" in e.get_language() or "pinyin" in e.get_name()
    ]
    print("Available zh/pinyin engines:", zh_engines)

settings = Gio.Settings.new("org.gnome.desktop.input-sources")
settings.set_value("sources", GLib.Variant("a(ss)", [("xkb", "us")]))
Gio.Settings.sync()
time.sleep(0.5)

target_sources = GLib.Variant("a(ss)", [("ibus", "libpinyin"), ("xkb", "us")])
settings.set_value("sources", target_sources)
settings.set_value("mru-sources", target_sources)
Gio.Settings.sync()
time.sleep(1.0)

if bus and bus.is_connected():
    ok = bus.set_global_engine("libpinyin")
    print("set_global_engine('libpinyin'):", ok)
    ge = bus.get_global_engine()
    print("Current global engine:", ge.get_name() if ge else None)

print("Active input sources:", settings.get_value("sources"))
