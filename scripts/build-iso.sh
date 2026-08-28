#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"

BASE_ISO="xubuntu-24.04.4-desktop-amd64.iso"
BASE_URL="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/${BASE_ISO}"

WORKDIR="$PWD/build"
BASE_PATH="$WORKDIR/$BASE_ISO"

SQUASH_ISO_PATH="/casper/minimal.standard.live.squashfs"

OLD_SQUASH="$WORKDIR/original.squashfs"
NEW_SQUASH="$WORKDIR/minimal.standard.live.squashfs"
SQUASH_ROOT="$WORKDIR/squashfs"
NEW_SIZE="$WORKDIR/filesystem.size"

OUTPUT_DIR="$PWD/output"
OUTPUT_ISO="$OUTPUT_DIR/LollyOS-${VERSION}-ubuntu-noble-amd64.iso"

echo "========================================"
echo " LollyOS ${VERSION}"
echo " Xubuntu 24.04.4 LTS remaster"
echo "========================================"

#
# 1. MUNKAKORNYEZET
#

echo
echo "[1/9] Munkakornyezet elokeszitese..."

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
mkdir -p "$OUTPUT_DIR"

rm -f "$OUTPUT_ISO"
rm -f "$OUTPUT_ISO.sha256"

#
# 2. XUBUNTU ISO
#

echo
echo "[2/9] Xubuntu 24.04.4 ISO letoltese..."

curl \
    -L \
    --fail \
    --retry 3 \
    --retry-delay 3 \
    "$BASE_URL" \
    -o "$BASE_PATH"

if [ ! -s "$BASE_PATH" ]; then
    echo "HIBA: A Xubuntu ISO letoltese sikertelen."
    exit 1
fi

echo
echo "Xubuntu ISO letoltve:"
ls -lh "$BASE_PATH"

#
# 3. SQUASHFS KINYERESE
#

echo
echo "[3/9] Live rendszer kinyerese..."

echo "Hasznalt live SquashFS:"
echo "$SQUASH_ISO_PATH"

xorriso \
    -osirrox on \
    -indev "$BASE_PATH" \
    -extract "$SQUASH_ISO_PATH" "$OLD_SQUASH"

if [ ! -s "$OLD_SQUASH" ]; then
    echo "HIBA: Nem sikerult kinyerni a live SquashFS-t."
    exit 1
fi

echo
echo "SquashFS sikeresen kinyerve:"
ls -lh "$OLD_SQUASH"

#
# 4. SQUASHFS KIBONTASA
#

echo
echo "[4/9] Live rendszer kibontasa..."

rm -rf "$SQUASH_ROOT"

unsquashfs \
    -d "$SQUASH_ROOT" \
    "$OLD_SQUASH"

if [ ! -d "$SQUASH_ROOT/etc" ]; then
    echo "HIBA: A live rendszer kibontasa sikertelen."
    exit 1
fi

rm -f "$OLD_SQUASH"

echo
echo "Live rendszer kibontva."

#
# 5. LOLLYOS FAJLOK
#

echo
echo "[5/9] LollyOS telepitese a live rendszerbe..."

mkdir -p "$SQUASH_ROOT/etc/lollyos"
mkdir -p "$SQUASH_ROOT/etc/sudoers.d"

#
# Repo sajat rendszerfajljai
#

if [ -d "$PWD/config/includes.chroot" ]; then

    echo "config/includes.chroot masolasa..."

    rsync \
        -a \
        "$PWD/config/includes.chroot/" \
        "$SQUASH_ROOT/"

else

    echo "FIGYELEM: config/includes.chroot nem talalhato."

fi

#
# LollyOS OS informacio
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

#
# LollyOS verzio
#

echo "$VERSION" > "$SQUASH_ROOT/etc/lollyos/version"

#
# Hostname
#

echo "lollyos" > "$SQUASH_ROOT/etc/hostname"

#
# Live sudo
#

cat > "$SQUASH_ROOT/etc/sudoers.d/lolly-live" <<EOF
lolly ALL=(ALL) NOPASSWD: ALL
EOF

chmod 440 "$SQUASH_ROOT/etc/sudoers.d/lolly-live"

#
# Lolly updater executable
#

if [ -f "$SQUASH_ROOT/usr/local/bin/lolly-update" ]; then

    chmod +x "$SQUASH_ROOT/usr/local/bin/lolly-update"

    echo "LollyOS updater megtalalva."

fi

#
# NetworkManager autostart desktop file
#

if [ -f "$SQUASH_ROOT/etc/xdg/autostart/nm-applet.desktop" ]; then
    chmod 644 "$SQUASH_ROOT/etc/xdg/autostart/nm-applet.desktop"
fi

echo
echo "LollyOS rendszerfajlok telepitve."

#
# 6. UJ SQUASHFS
#

echo
echo "[6/9] Uj LollyOS SquashFS epitese..."

rm -f "$NEW_SQUASH"

mksquashfs \
    "$SQUASH_ROOT" \
    "$NEW_SQUASH" \
    -comp xz \
    -b 131072 \
    -noappend

if [ ! -s "$NEW_SQUASH" ]; then
    echo "HIBA: Az uj SquashFS nem keszult el."
    exit 1
fi

echo
echo "Uj LollyOS SquashFS:"
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

if [ ! -s "$NEW_SIZE" ]; then
    echo "HIBA: filesystem.size generalasa sikertelen."
    exit 1
fi

echo
echo "filesystem.size:"
cat "$NEW_SIZE"

#
# Hely felszabaditasa
#

rm -rf "$SQUASH_ROOT"

#
# 7. ISO EPITES
#

echo
echo "[7/9] Bootolhato LollyOS ISO epitese..."

echo
echo "Az eredeti Xubuntu bootstruktura megmarad."
echo "Csak a live rendszer kerul lecserelesre."
echo

rm -f "$OUTPUT_ISO"

#
# Az xorriso bizonyos boot replay figyelmeztetesek miatt
# 32-es exit kodot adhat akkor is, ha az ISO tenylegesen
# sikeresen kiirodott.
#
# Ezert ideiglenesen kikapcsoljuk a set -e-t.
#

set +e

xorriso \
    -indev "$BASE_PATH" \
    -outdev "$OUTPUT_ISO" \
    -boot_image any replay \
    -rm "$SQUASH_ISO_PATH" \
    -map "$NEW_SQUASH" "$SQUASH_ISO_PATH" \
    -rm /casper/filesystem.size \
    -map "$NEW_SIZE" /casper/filesystem.size \
    -commit

XORRISO_EXIT=$?

set -e

echo
echo "xorriso exit code: $XORRISO_EXIT"

#
# Az ISO-nak mindenkeppen leteznie kell.
#

if [ ! -s "$OUTPUT_ISO" ]; then

    echo
    echo "========================================"
    echo " HIBA"
    echo "========================================"
    echo
    echo "Az ISO nem keszult el."
    echo "xorriso exit code: $XORRISO_EXIT"

    exit 1

fi

echo
echo "ISO fajl sikeresen letrejott:"
ls -lh "$OUTPUT_ISO"

if [ "$XORRISO_EXIT" -ne 0 ]; then

    echo
    echo "FIGYELEM:"
    echo "xorriso nem 0 exit kodot adott: $XORRISO_EXIT"
    echo
    echo "Az ISO azonban letrejott."
    echo "Most ellenorizzuk a bootstrukturat."

fi

#
# 8. BOOT ELLENORZES
#

echo
echo "[8/9] ISO bootstruktura ellenorzese..."

BOOT_REPORT="$WORKDIR/boot-report.txt"

set +e

xorriso \
    -indev "$OUTPUT_ISO" \
    -report_el_torito plain \
    2>&1 | tee "$BOOT_REPORT"

BOOT_CHECK_EXIT=${PIPESTATUS[0]}

set -e

if [ "$BOOT_CHECK_EXIT" -ne 0 ]; then

    echo
    echo "HIBA: Az ISO boot informacioja nem olvashato."
    exit 1

fi

echo
echo "Boot report sikeresen kiolvasva."

#
# Ellenorizzuk, hogy van-e El Torito boot bejegyzes.
#

if ! grep -qi "El Torito" "$BOOT_REPORT"; then

    echo
    echo "HIBA: Nem talalhato El Torito boot informacio."
    exit 1

fi

echo "El Torito boot informacio: OK"

#
# ISO fajlrendszer ellenorzes
#

echo
echo "Casper fajlok ellenorzese..."

xorriso \
    -indev "$OUTPUT_ISO" \
    -find /casper -type f -exec lsdl

#
# Ellenorizzuk, hogy az uj SquashFS benne van-e.
#

set +e

xorriso \
    -indev "$OUTPUT_ISO" \
    -find "$SQUASH_ISO_PATH" \
    -type f \
    -exec lsdl \
    > "$WORKDIR/squash-check.txt" 2>&1

SQUASH_CHECK_EXIT=$?

set -e

if [ "$SQUASH_CHECK_EXIT" -ne 0 ]; then

    echo
    echo "HIBA: A LollyOS SquashFS nem talalhato az ISO-ban."
    cat "$WORKDIR/squash-check.txt"
    exit 1

fi

cat "$WORKDIR/squash-check.txt"

echo
echo "LollyOS SquashFS: OK"

#
# 9. SHA256
#

echo
echo "[9/9] SHA256 keszitese..."

sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

if [ ! -s "$OUTPUT_ISO.sha256" ]; then
    echo "HIBA: SHA256 generalasa sikertelen."
    exit 1
fi

echo
echo "========================================"
echo " LOLLYOS BUILD KESZ"
echo "========================================"
echo

echo "ISO:"
ls -lh "$OUTPUT_ISO"

echo
echo "SHA256:"
cat "$OUTPUT_ISO.sha256"

echo
echo "Boot ellenorzes: OK"
echo "SquashFS ellenorzes: OK"

if [ "$XORRISO_EXIT" -eq 0 ]; then
    echo "xorriso: OK"
else
    echo "xorriso figyelmeztetessel fejezodott be: $XORRISO_EXIT"
fi

echo
echo "Kimenet:"
echo "$OUTPUT_ISO"
echo
echo "LollyOS ${VERSION} build befejezve."
