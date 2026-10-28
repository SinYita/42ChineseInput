#!/usr/bin/env bash
set -euo pipefail

IBUS_ROOT="${HOME}/.ibus"
TMP_DEB_DIR="$(mktemp -d /tmp/ibus-deb.XXXXXX)"
TMP_EXTRACT_DIR="$(mktemp -d /tmp/ibus-extract.XXXXXX)"
SYMLINK_BASE="/tmp/i$(id -u)"

cleanup() {
    rm -rf "${TMP_DEB_DIR}" "${TMP_EXTRACT_DIR}"
}
trap cleanup EXIT

echo "[1/6] Downloading ibus-libpinyin and dependencies via apt-get..."
(
    cd "${TMP_DEB_DIR}"
    apt-get download \
        ibus-libpinyin \
        libpinyin13 \
        libpinyin-data \
        libopencc1.1 \
        libopencc-data \
        libmarisa0
)

echo "[2/6] Extracting packages into ${IBUS_ROOT}..."
for deb in "${TMP_DEB_DIR}"/*.deb; do
    dpkg-deb -x "${deb}" "${TMP_EXTRACT_DIR}"
done

mkdir -p \
    "${IBUS_ROOT}/lib" \
    "${IBUS_ROOT}/libexec" \
    "${IBUS_ROOT}/component" \
    "${HOME}/.local/share/glib-2.0/schemas" \
    "${HOME}/.config/environment.d" \
    "${HOME}/.config/systemd/user/org.freedesktop.IBus.session.GNOME.service.d"

rm -rf "${IBUS_ROOT}/share" "${IBUS_ROOT}/oc"
cp -a "${TMP_EXTRACT_DIR}/usr/share/ibus-libpinyin" "${IBUS_ROOT}/share"
cp -a "${TMP_EXTRACT_DIR}/usr/share/opencc" "${IBUS_ROOT}/oc"
cp -a "${TMP_EXTRACT_DIR}/usr/lib/x86_64-linux-gnu/"* "${IBUS_ROOT}/lib/"
cp -a "${TMP_EXTRACT_DIR}/usr/libexec/ibus-engine-libpinyin" "${IBUS_ROOT}/libexec/ibus-engine-libpinyin.bin"
cp -a "${TMP_EXTRACT_DIR}/usr/share/glib-2.0/schemas/"*.xml "${HOME}/.local/share/glib-2.0/schemas/"

ln -sfn "${IBUS_ROOT}" "${SYMLINK_BASE}"

echo "[3/6] Compiling GSettings schemas..."
glib-compile-schemas "${HOME}/.local/share/glib-2.0/schemas/"

echo "[4/6] Patching hardcoded /usr paths in ELF binaries..."
python3 - "${IBUS_ROOT}" "${SYMLINK_BASE}" <<'EOF'
import glob
import os
import sys

ibus_root = sys.argv[1]
sym_base = sys.argv[2].encode("ascii")


def pad_path(base: bytes, suffix: bytes, target_len: int) -> bytes:
    raw = base + b"/" + suffix
    if len(raw) > target_len:
        raise ValueError(f"Replacement {raw!r} ({len(raw)}) exceeds {target_len} bytes")
    extra_slashes = target_len - len(raw) + 1
    result = base + (b"/" * extra_slashes) + suffix
    assert len(result) == target_len
    return result


pairs = [
    (
        b"/usr/share/ibus-libpinyin",
        pad_path(sym_base, b"share", len(b"/usr/share/ibus-libpinyin")),
    ),
    (
        b"/usr/lib/x86_64-linux-gnu/libpinyin/data",
        pad_path(sym_base, b"lib/libpinyin/data", len(b"/usr/lib/x86_64-linux-gnu/libpinyin/data")),
    ),
    (
        b"/usr/libexec/ibus-setup-libpinyin",
        pad_path(sym_base, b"setup-libpinyin", len(b"/usr/libexec/ibus-setup-libpinyin")),
    ),
    (
        b"/usr/share//opencc//",
        pad_path(sym_base, b"oc/", len(b"/usr/share//opencc//")),
    ),
]

targets = [os.path.join(ibus_root, "libexec", "ibus-engine-libpinyin.bin")]
targets.extend(glob.glob(os.path.join(ibus_root, "lib", "libopencc.so*")))

for path in targets:
    if os.path.islink(path) or not os.path.isfile(path):
        continue
    with open(path, "rb") as f:
        data = f.read()
    for old, new in pairs:
        data = data.replace(old, new)
    with open(path, "wb") as f:
        f.write(data)
EOF
chmod +x "${IBUS_ROOT}/libexec/ibus-engine-libpinyin.bin"

echo "[5/6] Generating wrapper scripts and systemd user configuration..."
cat > "${IBUS_ROOT}/libexec/ibus-engine-libpinyin" <<EOF
#!/bin/sh
ln -sfn "${IBUS_ROOT}" "${SYMLINK_BASE}"
export LD_LIBRARY_PATH="${IBUS_ROOT}/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HOME}/.local/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="${HOME}/.local/share/glib-2.0/schemas"
exec "${IBUS_ROOT}/libexec/ibus-engine-libpinyin.bin" "\$@" 2>> "${IBUS_ROOT}/engine.log"
EOF

cat > "${IBUS_ROOT}/setup-libpinyin" <<EOF
#!/bin/sh
ln -sfn "${IBUS_ROOT}" "${SYMLINK_BASE}"
export LD_LIBRARY_PATH="${IBUS_ROOT}/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HOME}/.local/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="${HOME}/.local/share/glib-2.0/schemas"
export IBUS_PREFIX="${IBUS_ROOT}"
export IBUS_DATAROOTDIR="${IBUS_ROOT}"
export IBUS_LOCALEDIR=/usr/share/locale
export IBUS_PKGDATADIR="${IBUS_ROOT}/share"
cd "${IBUS_ROOT}/share/setup/"
exec /usr/bin/python3 main2.py "\$@"
EOF

chmod +x "${IBUS_ROOT}/libexec/ibus-engine-libpinyin" "${IBUS_ROOT}/setup-libpinyin"

cp -a /usr/share/ibus/component/*.xml "${IBUS_ROOT}/component/"
cat > "${IBUS_ROOT}/component/libpinyin.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<component>
	<name>org.freedesktop.IBus.Libpinyin</name>
	<description>Libpinyin Component</description>
	<exec>${IBUS_ROOT}/libexec/ibus-engine-libpinyin --ibus</exec>
	<version>1.12.1</version>
	<author>Peng Wu &lt;alexepico@gmail.com&gt;</author>
	<license>GPL</license>
	<homepage>https://github.com/libpinyin/ibus-libpinyin</homepage>
	<textdomain>ibus-libpinyin</textdomain>
	<engines>
		<engine>
			<name>libpinyin</name>
			<language>zh_CN</language>
			<license>GPL</license>
			<author>Peng Wu</author>
			<icon>${IBUS_ROOT}/share/icons/ibus-pinyin.svg</icon>
			<layout>default</layout>
			<longname>Intelligent Pinyin</longname>
			<description>Intelligent Pinyin input method</description>
			<rank>99</rank>
			<symbol>&#x62FC;</symbol>
			<icon_prop_key>InputMode</icon_prop_key>
			<setup>${IBUS_ROOT}/setup-libpinyin libpinyin</setup>
			<textdomain>ibus-libpinyin</textdomain>
		</engine>
		<engine>
			<name>libbopomofo</name>
			<language>zh_TW</language>
			<license>GPL</license>
			<author>Peng Wu</author>
			<icon>${IBUS_ROOT}/share/icons/ibus-bopomofo.svg</icon>
			<layout>default</layout>
			<longname>Bopomofo</longname>
			<description>Bopomofo input method</description>
			<rank>98</rank>
			<symbol>&#x3109;</symbol>
			<icon_prop_key>InputMode</icon_prop_key>
			<setup>${IBUS_ROOT}/setup-libpinyin libbopomofo</setup>
			<textdomain>ibus-libpinyin</textdomain>
		</engine>
	</engines>
</component>
EOF

