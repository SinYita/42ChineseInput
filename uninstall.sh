#!/usr/bin/env bash
set -euo pipefail

echo "Restoring default English (US) input source..."
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]" || true
gsettings reset org.gnome.desktop.input-sources mru-sources || true

echo "Removing rootless ibus-libpinyin files and configuration..."
rm -rf \
    "${HOME}/.ibus" \
    "/tmp/i$(id -u)" \
    "${HOME}/.config/environment.d/ibus-libpinyin.conf" \
    "${HOME}/.config/systemd/user/org.freedesktop.IBus.session.GNOME.service.d/override.conf" \
    "${HOME}/.local/share/glib-2.0/schemas/com.github.libpinyin.ibus-libpinyin.gschema.xml"

if [ -d "${HOME}/.local/share/glib-2.0/schemas" ]; then
    glib-compile-schemas "${HOME}/.local/share/glib-2.0/schemas" || true
fi

ibus write-cache || true
systemctl --user daemon-reload || true
systemctl --user restart org.freedesktop.IBus.session.GNOME.service || true

echo "Uninstalled successfully."
