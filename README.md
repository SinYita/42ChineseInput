# 42ChineseInput

Install and activate **Chinese Intelligent Pinyin (`ibus-libpinyin`)** on Ubuntu / Debian (GNOME + IBus) **without `sudo` or root access**.

Designed for shared workstations, university clusters (e.g., 42 Network), and locked-down Linux desktops where `apt install` is restricted.

---

## Features

- **Zero Admin Privileges**: Uses `apt-get download` and `dpkg-deb -x` to unpack `ibus-libpinyin`, `libpinyin`, `libopencc`, and `libmarisa` directly into `~/.ibus`.
- **In-Place ELF Path Patching**: Rewrites hardcoded `/usr/...` asset and dictionary paths inside `ibus-engine-libpinyin` and `libopencc.so` to user-space paths of identical byte length—no `chroot`, `bwrap`, or `LD_PRELOAD` overhead required.
- **Systemd User Service Integration**: Injects `IBUS_COMPONENT_PATH`, `LD_LIBRARY_PATH`, and `GSETTINGS_SCHEMA_DIR` into `org.freedesktop.IBus.session.GNOME.service` via a user-level drop-in (`override.conf`).
- **One-Command Activation**: Automatically compiles GSettings schemas, updates the IBus registry cache, restarts the IBus user daemon, and registers `('ibus', 'libpinyin')` in GNOME Input Sources.

---

## Quick Start

### 1. Install & Activate

```bash
git clone https://github.com/SinYita/42ChineseInput.git
cd 42ChineseInput
./install.sh
```

### 2. Re-activate (Optional)

Your configuration persists across logins in `~/.ibus` and `~/.config`. If a cluster machine resets your desktop session state, run:

```bash
./activate.py
```

### 3. Uninstall

```bash
./uninstall.sh
```

---

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| Switch between English (`en`) and Chinese (`拼`) input sources | `Super (Win) + Space` |
| Toggle Chinese / English mode inside Intelligent Pinyin | `Shift` |
| Page up / Page down through candidates | `,` / `.` or `-` / `=` |

---

## How It Works

1. **Package Acquisition**: Downloads `.deb` archives for `ibus-libpinyin`, `libpinyin13`, `libpinyin-data`, `libopencc1.1`, `libopencc-data`, and `libmarisa0` using `apt-get download` (which requires no root privileges).
2. **Binary Relocation**: `ibus-engine-libpinyin` and `libopencc` contain compiled-in `/usr/share/...` and `/usr/lib/...` paths in `.rodata`. The installer replaces these prefixes with a fixed-length user symlink path (`/tmp/i<UID>/...` -> `~/.ibus/...`) padded with POSIX-compliant `/` characters so ELF section offsets remain unchanged.
3. **Schema & Component Registration**: Compiles `com.github.libpinyin.ibus-libpinyin.gschema.xml` into `~/.local/share/glib-2.0/schemas` and registers `libpinyin.xml` under `~/.ibus/component`.
4. **Daemon & GNOME Shell Sync**: Reloads `org.freedesktop.IBus.session.GNOME.service` via `systemctl --user` and updates `org.gnome.desktop.input-sources` via ` Gio.Settings`.

---

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04 (or Debian with GNOME + IBus pre-installed)
- Standard user-space utilities: `apt-get`, `dpkg-deb`, `python3`, `python3-gi`, `glib-compile-schemas`

---

## License

[MIT](./LICENSE)
