#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"

BASE_ISO="xubuntu-24.04.4-desktop-amd64.iso"
BASE_URL="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/${BASE_ISO}"

WORKDIR="$PWD/build"
BASE_PATH="$WORKDIR/$BASE_ISO"

SQUASH_ISO_PATH="/casper/minimal.standard.live.squashfs"
OLD_SQUASH="$WORKDIR/original.squashfs"
NEW_SQUASH="$WORKDIR/filesystem-new.squashfs"
SQUASH_ROOT="$WORKDIR/squashfs"

NEW_SIZE="$WORKDIR/filesystem.size"

OUTPUT_DIR="$PWD/output"
OUTPUT_ISO="$OUTPUT_DIR/LollyOS-${VERSION}-ubuntu-noble-amd64.iso"

echo "========================================"
echo " LollyOS ${VERSION}"
echo " Xubuntu 24.04.4 LTS remaster"
echo "========================================"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
mkdir -p "$OUTPUT_DIR"

echo
echo "[1/8] Xubuntu 24.04.4 ISO letoltese..."

curl \
    -L \
    --fail \
    --retry 3 \
    --retry-delay 3 \
    "$BASE_URL" \
    -o "$BASE_PATH"

if [ ! -f "$BASE_PATH" ]; then
    echo "HIBA: A Xubuntu ISO letoltese sikertelen."
    exit 1
fi

echo
echo "ISO letoltve:"
ls -lh "$BASE_PATH"

echo
echo "[2/8] Xubuntu live rendszer ellenorzese..."

echo "Hasznalt SquashFS:"
echo "$SQUASH_ISO_PATH"

xorriso \
    -indev "$BASE_PATH" \
    -find /casper -type f -exec lsdl

echo
echo "[3/8] Live SquashFS kinyerese..."

rm -f "$OLD_SQUASH"

xorriso \
    -osirrox on \
    -indev "$BASE_PATH" \
    -extract "$SQUASH_ISO_PATH" "$OLD_SQUASH"

if [ ! -f "$OLD_SQUASH" ]; then
    echo "HIBA: Nem sikerult kinyerni:"
    echo "$SQUASH_ISO_PATH"
    exit 1
fi

echo
echo "SquashFS kinyerve:"
ls -lh "$OLD_SQUASH"

echo
echo "[4/8] Live rendszer kibontasa..."

rm -rf "$SQUASH_ROOT"

unsquashfs \
    -d "$SQUASH_ROOT" \
    "$OLD_SQUASH"

if [ ! -d "$SQUASH_ROOT/etc" ]; then
    echo "HIBA: A SquashFS kibontasa sikertelen."
    exit 1
fi

# A regi squashfs mar nem kell.
rm -f "$OLD_SQUASH"

echo
echo "[5/8] LollyOS rendszer telepitese..."

mkdir -p "$SQUASH_ROOT/etc/lollyos"

echo "$VERSION" > "$SQUASH_ROOT/etc/lollyos/version"

cat > "$SQUASH_ROOT/etc/os-release" <<EOF
PRETTY_NAME="LollyOS ${VERSION}"
NAME="LollyOS"
VERSION_ID="${VERSION}"
VERSION="${VERSION} (Ubuntu Noble)"
VERSION_CODENAME=noble
ID=lollyos
ID_LIKE="ubuntu debian"
UBUNTU_CODENAME=noble
HOME_URL="https://github.com/zairoodev-cyber/LollyOS"
SUPPORT_URL="https://github.com/zairoodev-cyber/LollyOS/issues"
BUG_REPORT_URL="https://github.com/zairoodev-cyber/LollyOS/issues"
EOF

echo "lollyos" > "$SQUASH_ROOT/etc/hostname"

#
# Repo sajat LollyOS rendszerfajljai
#

if [ -d "$PWD/config/includes.chroot" ]; then

    echo
    echo "LollyOS rendszerfajlok masolasa..."

    rsync \
        -a \
        "$PWD/config/includes.chroot/" \
        "$SQUASH_ROOT/"

fi

#
# Biztosan LollyOS maradjon az os-release akkor is,
# ha includes.chroot tartalmaz sajat verziot.
#

cat > "$SQUASH_ROOT/etc/os-release" <<EOF
PRETTY_NAME="LollyOS ${VERSION}"
NAME="LollyOS"
VERSION_ID="${VERSION}"
VERSION="${VERSION} (Ubuntu Noble)"
VERSION_CODENAME=noble
ID=lollyos
ID_LIKE="ubuntu debian"
UBUNTU_CODENAME=noble
HOME_URL="https://github.com/zairoodev-cyber/LollyOS"
SUPPORT_URL="https://github.com/zairoodev-cyber/LollyOS/issues"
BUG_REPORT_URL="https://github.com/zairoodev-cyber/LollyOS/issues"
EOF

echo "$VERSION" > "$SQUASH_ROOT/etc/lollyos/version"
echo "lollyos" > "$SQUASH_ROOT/etc/hostname"

#
# Live user sudo
#

mkdir -p "$SQUASH_ROOT/etc/sudoers.d"

cat > "$SQUASH_ROOT/etc/sudoers.d/lolly-live" <<EOF
lolly ALL=(ALL) NOPASSWD: ALL
EOF

chmod 440 "$SQUASH_ROOT/etc/sudoers.d/lolly-live"

#
# Executable bitek
#

if [ -f "$SQUASH_ROOT/usr/local/bin/lolly-update" ]; then
    chmod +x "$SQUASH_ROOT/usr/local/bin/lolly-update"
fi

echo
echo "LollyOS branding kesz."

echo
echo "[6/8] Uj SquashFS epitese..."

rm -f "$NEW_SQUASH"

mksquashfs \
    "$SQUASH_ROOT" \
    "$NEW_SQUASH" \
    -comp xz \
    -b 131072 \
    -noappend

if [ ! -f "$NEW_SQUASH" ]; then
    echo "HIBA: Az uj SquashFS nem keszult el."
    exit 1
fi

echo
echo "Uj SquashFS:"
ls -lh "$NEW_SQUASH"

#
# filesystem.size
#

du \
    -sx \
    --block-size=1 \
    "$SQUASH_ROOT" \
    | cut -f1 \
    > "$NEW_SIZE"

echo
echo "filesystem.size:"
cat "$NEW_SIZE"

#
# Hely felszabaditasa az ISO generalas elott.
#

rm -rf "$SQUASH_ROOT"

echo
echo "[7/8] Bootolhato LollyOS ISO epitese..."

rm -f "$OUTPUT_ISO"

#
# FONTOS:
#
# Az eredeti Xubuntu ISO-t nyitjuk meg.
#
# NEM bontjuk ki es epitjuk ujra az egesz ISO-t,
# mert az tonkretenne a GRUB / EFI / El Torito
# boot strukturat.
#
# Csak a live SquashFS es a filesystem.size
# kerul lecserelesre.
#

xorriso \
    -indev "$BASE_PATH" \
    -outdev "$OUTPUT_ISO" \
    -boot_image any replay \
    -rm "$SQUASH_ISO_PATH" \
    -map "$NEW_SQUASH" "$SQUASH_ISO_PATH" \
    -rm /casper/filesystem.size \
    -map "$NEW_SIZE" /casper/filesystem.size \
    -commit

if [ ! -f "$OUTPUT_ISO" ]; then
    echo "HIBA: A LollyOS ISO nem keszult el."
    exit 1
fi

echo
echo "[8/8] ISO ellenorzes..."

echo
echo "ISO boot informacio:"

xorriso \
    -indev "$OUTPUT_ISO" \
    -report_el_torito plain

echo
echo "Casper tartalom:"

xorriso \
    -indev "$OUTPUT_ISO" \
    -find /casper -type f -exec lsdl

echo
echo "SHA256 keszitese..."

sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo
echo "========================================"
echo " LOLLYOS BUILD KESZ"
echo "========================================"
echo

ls -lh "$OUTPUT_ISO"
ls -lh "$OUTPUT_ISO.sha256"

echo
echo "ISO:"
echo "$OUTPUT_ISO"

echo
echo "SHA256:"
cat "$OUTPUT_ISO.sha256"
