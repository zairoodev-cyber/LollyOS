#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"

BASE_ISO="xubuntu-24.04.4-desktop-amd64.iso"
BASE_URL="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/${BASE_ISO}"

WORKDIR="$PWD/build"
ISO_ROOT="$WORKDIR/iso"
SQUASH_ROOT="$WORKDIR/squashfs"

OUTPUT_DIR="$PWD/output"
OUTPUT_ISO="$OUTPUT_DIR/LollyOS-${VERSION}-ubuntu-noble-amd64.iso"

echo "========================================"
echo " LollyOS ${VERSION} ISO Builder"
echo " Base: Xubuntu 24.04.4 LTS"
echo "========================================"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$OUTPUT_DIR"

echo "[1/8] Xubuntu ISO letöltése..."
curl -L --fail --retry 3 \
  "$BASE_URL" \
  -o "$WORKDIR/$BASE_ISO"

echo "[2/8] ISO kibontása..."
mkdir -p "$ISO_ROOT"

xorriso \
  -osirrox on \
  -indev "$WORKDIR/$BASE_ISO" \
  -extract / "$ISO_ROOT"

chmod -R u+w "$ISO_ROOT"

echo "[3/8] Live filesystem kibontása..."
unsquashfs \
  -d "$SQUASH_ROOT" \
  "$ISO_ROOT/casper/filesystem.squashfs"

echo "[4/8] LollyOS rendszerfájlok telepítése..."

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

echo "[5/8] Repository LollyOS fájlok másolása..."

if [ -d "$PWD/config/includes.chroot" ]; then
    rsync -a \
      "$PWD/config/includes.chroot/" \
      "$SQUASH_ROOT/"
fi

echo "[6/8] SquashFS újraépítése..."

rm -f "$ISO_ROOT/casper/filesystem.squashfs"

mksquashfs \
  "$SQUASH_ROOT" \
  "$ISO_ROOT/casper/filesystem.squashfs" \
  -comp xz \
  -noappend

echo "[7/8] filesystem.size frissítése..."

du -sx --block-size=1 "$SQUASH_ROOT" \
  | cut -f1 \
  > "$ISO_ROOT/casper/filesystem.size"

echo "[8/8] Bootolható ISO újraépítése..."

rm -f "$OUTPUT_ISO"

xorriso \
  -indev "$WORKDIR/$BASE_ISO" \
  -outdev "$OUTPUT_ISO" \
  -map "$ISO_ROOT" / \
  -boot_image any replay

sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo
echo "========================================"
echo " BUILD KÉSZ"
echo "========================================"
ls -lh "$OUTPUT_ISO"
ls -lh "$OUTPUT_ISO.sha256"