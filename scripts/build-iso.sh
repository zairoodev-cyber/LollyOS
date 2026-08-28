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
mkdir -p "$WORKDIR" "$OUTPUT_DIR" "$ISO_ROOT"

echo "[1/9] Xubuntu ISO letöltése..."

curl -L --fail --retry 3 \
  "$BASE_URL" \
  -o "$WORKDIR/$BASE_ISO"

echo "[2/9] ISO tartalmának kibontása..."

xorriso \
  -osirrox on \
  -indev "$WORKDIR/$BASE_ISO" \
  -extract / "$ISO_ROOT"

chmod -R u+w "$ISO_ROOT"

echo
echo "===== CASPER TARTALMA ====="
find "$ISO_ROOT/casper" -maxdepth 1 -type f -printf "%f\n" || true
echo "==========================="
echo

echo "[3/9] Live SquashFS megkeresése..."

SQUASH_FILE=""

for candidate in \
  "$ISO_ROOT/casper/filesystem.squashfs" \
  "$ISO_ROOT/casper/minimal.standard.live.squashfs" \
  "$ISO_ROOT/casper/minimal.standard.live.squashfs"; do

  if [ -f "$candidate" ]; then
    SQUASH_FILE="$candidate"
    break
  fi

done

if [ -z "$SQUASH_FILE" ]; then
  SQUASH_FILE="$(find "$ISO_ROOT/casper" \
    -maxdepth 1 \
    -type f \
    -name "*.squashfs" \
    | head -n 1 || true)"
fi

if [ -z "$SQUASH_FILE" ] || [ ! -f "$SQUASH_FILE" ]; then
  echo "ERROR: Nem találtam SquashFS fájlt a casper mappában."
  echo
  find "$ISO_ROOT/casper" -maxdepth 2 -type f || true
  exit 1
fi

echo "Megtalált SquashFS:"
echo "$SQUASH_FILE"

SQUASH_FILENAME="$(basename "$SQUASH_FILE")"

echo "[4/9] SquashFS kibontása..."

unsquashfs \
  -d "$SQUASH_ROOT" \
  "$SQUASH_FILE"

echo "[5/9] LollyOS branding telepítése..."

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

echo "[6/9] Repository rendszerfájlok másolása..."

if [ -d "$PWD/config/includes.chroot" ]; then
  rsync -a \
    "$PWD/config/includes.chroot/" \
    "$SQUASH_ROOT/"
fi

echo "[7/9] SquashFS újraépítése..."

rm -f "$SQUASH_FILE"

mksquashfs \
  "$SQUASH_ROOT" \
  "$SQUASH_FILE" \
  -comp xz \
  -noappend

echo "[8/9] filesystem.size frissítése..."

du -sx --block-size=1 "$SQUASH_ROOT" \
  | cut -f1 \
  > "$ISO_ROOT/casper/filesystem.size"

echo "[9/9] Bootolható ISO újraépítése..."

rm -f "$OUTPUT_ISO"

xorriso \
  -indev "$WORKDIR/$BASE_ISO" \
  -outdev "$OUTPUT_ISO" \
  -map "$ISO_ROOT" / \
  -boot_image any replay

sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo
echo "========================================"
echo " LollyOS BUILD KÉSZ"
echo "========================================"

ls -lh "$OUTPUT_ISO"
ls -lh "$OUTPUT_ISO.sha256"