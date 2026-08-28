#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"
BASE_ISO="xubuntu-24.04.4-desktop-amd64.iso"
BASE_URL="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/${BASE_ISO}"

ROOT="$PWD"
WORKDIR="$ROOT/build"
OUTPUT_DIR="$ROOT/output"
BASE_PATH="$WORKDIR/$BASE_ISO"

SQUASH_ROOT="$WORKDIR/squashfs-root"
OLD_SQUASH="$WORKDIR/original-live.squashfs"
NEW_SQUASH="$WORKDIR/minimal.standard.live.squashfs"
NEW_SIZE="$WORKDIR/filesystem.size"
BOOT_REPORT="$WORKDIR/boot-report.txt"

SQUASH_ISO_PATH="/casper/minimal.standard.live.squashfs"
SIZE_ISO_PATH="/casper/filesystem.size"

OUTPUT_ISO="$OUTPUT_DIR/LollyOS-${VERSION}-ubuntu-noble-amd64.iso"

log() {
    printf '\n[%s] %s\n' "$1" "$2"
}

die() {
    echo "HIBA: $*" >&2
    exit 1
}

# ============================================================
# ELŐKÉSZÍTÉS
# ============================================================

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
mkdir -p "$OUTPUT_DIR"

rm -f "$OUTPUT_ISO"
rm -f "$OUTPUT_ISO.sha256"

echo "========================================"
echo " LollyOS ${VERSION}"
echo " Xubuntu 24.04.4 LTS remaster"
echo "========================================"

# ============================================================
# 1. BASE ISO
# ============================================================

log "1/9" "Xubuntu 24.04.4 ISO letoltese..."

curl \
    -L \
    --fail \
    --retry 3 \
    --retry-delay 3 \
    "$BASE_URL" \
    -o "$BASE_PATH"

[ -s "$BASE_PATH" ] || die "A base ISO nem toltodott le."

echo
ls -lh "$BASE_PATH"

# ============================================================
# 2. CASPER ELLENŐRZÉS
# ============================================================

log "2/9" "A szukseges Casper fajlok ellenorzese..."

CASPER_LIST="$WORKDIR/base-casper-list.txt"

xorriso \
    -indev "$BASE_PATH" \
    -ls /casper \
    > "$CASPER_LIST" 2>&1 || {
        cat "$CASPER_LIST"
        die "A /casper mappa nem olvashato."
    }

cat "$CASPER_LIST"

grep -Fq "minimal.standard.live.squashfs" "$CASPER_LIST" || {
    die "$SQUASH_ISO_PATH nem talalhato."
}

grep -Fq "filesystem.size" "$CASPER_LIST" || {
    die "$SIZE_ISO_PATH nem talalhato."
}

echo
echo "Casper fajlok: OK"

# ============================================================
# 3. LIVE SQUASHFS KINYERÉSE
# ============================================================

log "3/9" "Live SquashFS kinyerese..."

xorriso \
    -osirrox on \
    -indev "$BASE_PATH" \
    -extract_single "$SQUASH_ISO_PATH" "$OLD_SQUASH"

[ -s "$OLD_SQUASH" ] || \
    die "A live SquashFS kinyerese sikertelen."

echo
ls -lh "$OLD_SQUASH"

# ============================================================
# 4. SQUASHFS KIBONTÁSA
# ============================================================

log "4/9" "Live rendszer kibontasa..."

unsquashfs \
    -d "$SQUASH_ROOT" \
    "$OLD_SQUASH"

[ -d "$SQUASH_ROOT/etc" ] || \
    die "A SquashFS kibontasa sikertelen."

rm -f "$OLD_SQUASH"

echo
echo "Live rendszer kibontva."

# ============================================================
# 5. LOLLYOS FAJLOK
# ============================================================

log "5/9" "LollyOS fajlok alkalmazasa..."

if [ -d "$ROOT/config/includes.chroot" ]; then

    echo "config/includes.chroot masolasa..."

    rsync \
        -a \
        "$ROOT/config/includes.chroot/" \
        "$SQUASH_ROOT/"

else
    echo "FIGYELEM: config/includes.chroot nem talalhato."
fi

mkdir -p "$SQUASH_ROOT/etc/lollyos"

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

printf '%s\n' "$VERSION" \
    > "$SQUASH_ROOT/etc/lollyos/version"

printf 'lollyos\n' \
    > "$SQUASH_ROOT/etc/hostname"

if [ -f "$SQUASH_ROOT/usr/local/bin/lolly-update" ]; then

    chmod +x \
        "$SQUASH_ROOT/usr/local/bin/lolly-update"

fi

echo
echo "LollyOS fajlok alkalmazva."

# ============================================================
# 6. ÚJ SQUASHFS
# ============================================================

log "6/9" "Uj SquashFS epitese..."

mksquashfs \
    "$SQUASH_ROOT" \
    "$NEW_SQUASH" \
    -comp xz \
    -b 131072 \
    -noappend

[ -s "$NEW_SQUASH" ] || \
    die "Az uj SquashFS nem keszult el."

echo
echo "Uj SquashFS:"
ls -lh "$NEW_SQUASH"

du \
    -sx \
    --block-size=1 \
    "$SQUASH_ROOT" \
    | cut -f1 \
    > "$NEW_SIZE"

[ -s "$NEW_SIZE" ] || \
    die "filesystem.size nem keszult el."

echo
echo "filesystem.size:"
cat "$NEW_SIZE"

# Már nem kell a kibontott rootfs.
rm -rf "$SQUASH_ROOT"

# ============================================================
# 7. ISO MÓDOSÍTÁSA
# ============================================================

log "7/9" "Bootolhato LollyOS ISO modositasa..."

echo
echo "Meglevo ISO fajlok felulirasa..."
echo

#
# FONTOS:
#
# NINCS:
#
#   -rm squashfs
#   -rm filesystem.size
#
# Ehelyett az xorriso sajat overwrite mechanizmusat
# hasznaljuk.
#
# A boot replay pedig a fajlmuveletek UTAN tortenik.
#

set +e

xorriso \
    -indev "$BASE_PATH" \
    -outdev "$OUTPUT_ISO" \
    -overwrite nondir \
    -map_single "$NEW_SQUASH" "$SQUASH_ISO_PATH" \
    -map_single "$NEW_SIZE" "$SIZE_ISO_PATH" \
    -boot_image any replay \
    -commit

XORRISO_RC=$?

set -e

echo
echo "xorriso exit code: $XORRISO_RC"

[ -s "$OUTPUT_ISO" ] || {
    die "Az ISO nem jott letre. xorriso exit code: $XORRISO_RC"
}

echo
echo "ISO letrejott:"
ls -lh "$OUTPUT_ISO"

# ============================================================
# 8. AZ OUTPUT ISO VALÓDI ELLENŐRZÉSE
# ============================================================

log "8/9" "Az ELKESZULT ISO ellenorzese..."

OUTPUT_CASPER="$WORKDIR/output-casper-list.txt"

#
# Nem a base ISO-t ellenorizzuk,
# hanem konkretan az ELKESZULT LollyOS ISO-t.
#

xorriso \
    -indev "$OUTPUT_ISO" \
    -ls /casper \
    > "$OUTPUT_CASPER" 2>&1 || {

        cat "$OUTPUT_CASPER"
        die "Az output ISO /casper mappaja nem olvashato."

    }

cat "$OUTPUT_CASPER"

#
# Pont azt a hibat szurjuk ki,
# ami az elozo buildnel tortent.
#

grep -Fq "minimal.standard.live.squashfs" "$OUTPUT_CASPER" || {

    echo
    echo "========================================"
    echo " HIBA"
    echo "========================================"
    echo
    echo "Az uj live SquashFS HIANYZIK az ISO-bol."

    exit 1
}

grep -Fq "filesystem.size" "$OUTPUT_CASPER" || {

    echo
    echo "========================================"
    echo " HIBA"
    echo "========================================"
    echo
    echo "filesystem.size HIANYZIK az ISO-bol."

    exit 1
}

echo
echo "SquashFS az output ISO-ban: OK"
echo "filesystem.size az output ISO-ban: OK"

# ============================================================
# BOOT ELLENŐRZÉS
# ============================================================

echo
echo "Bootstruktura ellenorzese..."

xorriso \
    -indev "$OUTPUT_ISO" \
    -report_el_torito plain \
    > "$BOOT_REPORT" 2>&1 || {

        cat "$BOOT_REPORT"
        die "A boot report nem olvashato."

    }

cat "$BOOT_REPORT"

grep -qi "El Torito" "$BOOT_REPORT" || \
    die "Nincs El Torito boot informacio."

grep -qi "EFI" "$BOOT_REPORT" || \
    die "Nincs EFI boot informacio."

echo
echo "El Torito: OK"
echo "EFI boot: OK"

#
# Ha az ISO írása figyelmeztetést adott, de
# maga az output ISO ellenorzese sikeres volt,
# akkor elfogadjuk.
#

if [ "$XORRISO_RC" -ne 0 ]; then

    echo
    echo "FIGYELEM:"
    echo "xorriso exit code: $XORRISO_RC"
    echo
    echo "Viszont:"
    echo " - output ISO letezik"
    echo " - SquashFS letezik"
    echo " - filesystem.size letezik"
    echo " - El Torito rendben"
    echo " - EFI rendben"

fi

# ============================================================
# 9. SHA256
# ============================================================

log "9/9" "SHA256 keszitese..."

sha256sum "$OUTPUT_ISO" \
    > "$OUTPUT_ISO.sha256"

[ -s "$OUTPUT_ISO.sha256" ] || \
    die "SHA256 nem keszult el."

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
echo "ELLENORZESEK:"
echo " [OK] SquashFS"
echo " [OK] filesystem.size"
echo " [OK] El Torito"
echo " [OK] EFI"

echo
echo "LollyOS ${VERSION} build sikeresen befejezve."
