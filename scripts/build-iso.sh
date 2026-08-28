#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"

BASE_ISO="xubuntu-24.04.4-desktop-amd64.iso"
BASE_URL="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/${BASE_ISO}"

WORKDIR="$PWD/build"
BASE_PATH="$WORKDIR/$BASE_ISO"
SQUASH_ROOT="$WORKDIR/squashfs"
NEW_SQUASH="$WORKDIR/filesystem-new.squashfs"
NEW_SIZE="$WORKDIR/filesystem.size"

OUTPUT_DIR="$PWD/output"
OUTPUT_ISO="$OUTPUT_DIR/LollyOS-${VERSION}-ubuntu-noble-amd64.iso"

mkdir -p "$WORKDIR" "$OUTPUT_DIR"

cleanup() {
    rm -rf "$SQUASH_ROOT" || true
}
trap cleanup EXIT

echo "========================================"
echo " LollyOS ${VERSION}"
echo " Xubuntu 24.04.4 remaster"
echo "========================================"

echo "[1/8] Xubuntu letoltese..."

curl -L --fail --retry 3 \
    "$BASE_URL" \
    -o "$BASE_PATH"

echo
echo "[2/8] SquashFS fajl keresese az ISO-ban..."

xorriso -indev "$BASE_PATH" -find /casper -type f -exec lsdl

SQUASH_ISO_PATH="$(
    xorriso \
        -indev "$BASE_PATH" \
        -find /casper -type f -name '*.squashfs' -exec echo '{}' 2>/dev/null \
        | grep '^/casper/' \
        | head -n 1
)"

if [ -z "$SQUASH_ISO_PATH" ]; then
    echo "HIBA: Nem talalhato squashfs a /casper mappaban."
    exit 1
fi

echo "Live rendszer: $SQUASH_ISO_PATH"

echo
echo "[3/8] SquashFS kinyerese..."

OLD_SQUASH="$WORKDIR/original.squashfs"

rm -f "$OLD_SQUASH"

xorriso \
    -osirrox on \
    -indev "$BASE_PATH" \
    -extract "$SQUASH_ISO_PATH" "$OLD_SQUASH"

test -f "$OLD_SQUASH"

echo
echo "[4/8] Live rendszer kibontasa..."

rm -rf "$SQUASH_ROOT"

unsquashfs \
    -d "$SQUASH_ROOT" \
    "$OLD_SQUASH"

# A regi squashfs mar nem kell.
rm -f "$OLD_SQUASH"

echo
echo "[5/8] LollyOS fajlok telepitese..."

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

if [ -d "$PWD/config/includes.chroot" ]; then
    echo "LollyOS repository fajlok masolasa..."

    rsync -a \
        "$PWD/config/includes.chroot/" \
        "$SQUASH_ROOT/"
fi

echo
echo "[6/8] Uj SquashFS keszitese..."

rm -f "$NEW_SQUASH"

mksquashfs \
    "$SQUASH_ROOT" \
    "$NEW_SQUASH" \
    -comp xz \
    -noappend

du -sx --block-size=1 "$SQUASH_ROOT" \
    | cut -f1 \
    > "$NEW_SIZE"

echo "Uj SquashFS:"
ls -lh "$NEW_SQUASH"

# A kibontott rootfs mar nem kell, mielott az uj ISO keszul.
rm -rf "$SQUASH_ROOT"

echo
echo "[7/8] Eredeti Xubuntu bootstruktura megtartasa..."

rm -f "$OUTPUT_ISO"

#
# FONTOS:
# Nem bontjuk ki es nem mappoljuk vissza az egesz ISO-t.
#
# Az eredeti Xubuntu ISO marad a kiindulasi ISO.
# Csak a modositott SquashFS-t es filesystem.size fajlt csereljuk.
#
# Igy az eredeti GRUB / EFI / El Torito boot objektumok
# az ISO-n belul maradnak.
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

echo
echo "[8/8] Ellenorzes + SHA256..."

test -f "$OUTPUT_ISO"

xorriso \
    -indev "$OUTPUT_ISO" \
    -find /casper -type f -exec lsdl

sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo
echo "========================================"
echo " LOLLYOS ISO BUILD KESZ"
echo "========================================"
echo

ls -lh "$OUTPUT_ISO"
ls -lh "$OUTPUT_ISO.sha256"

echo
echo "ISO:"
echo "$OUTPUT_ISO"
