#!/sbin/sh
# The actual install, sourced by update-binary with $ZIP and ui_print/abort in
# scope. Kept separate so it can be read, reviewed and dry-run on its own:
#
#   A50_DRYRUN=1 A50_ZIP=/path/to.zip sh install/a50-install.sh
#
# Every step verifies. "dd returned 0" is not "the partition holds what I
# wrote", so the boot image is read back and hashed before anything reboots.

: "${ZIP:=${A50_ZIP:-}}"
: "${DRYRUN:=${A50_DRYRUN:-}}"
: "${TMP:=/tmp/a50-install}"
mkdir -p "$TMP"

# Standalone / dry-run: update-binary normally supplies these.
if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() { echo "$1"; }
    abort() { echo "!! $1" >&2; exit 1; }
fi

BOOT_PARTITION_BYTES=57671680
ROOTFS_TARGET=/data/rootfs.img

# --- 1. is this the right phone? -------------------------------------------
find_part() {
    for base in /dev/block/by-name /dev/block/bootdevice/by-name \
                /dev/block/platform/*/by-name /dev/disk/by-partlabel; do
        [ -e "$base/$1" ] && { readlink -f "$base/$1"; return 0; }
    done
    return 1
}

BOOT_DEV=$(find_part boot)   || abort "no boot partition found - is this an A50?"
DATA_DEV=$(find_part userdata) || abort "no userdata partition found"

boot_bytes=$(cat "/sys/class/block/$(basename "$BOOT_DEV")/size" 2>/dev/null)
boot_bytes=$((boot_bytes * 512))
ui_print "boot      $BOOT_DEV  ($boot_bytes bytes)"
ui_print "userdata  $DATA_DEV"

if [ "$boot_bytes" -ne "$BOOT_PARTITION_BYTES" ]; then
    abort "boot partition is $boot_bytes bytes, this port expects $BOOT_PARTITION_BYTES.
       That is not an SM-A505F, or the partition table has been changed."
fi

# --- 2. checksums shipped with the payload ---------------------------------
unzip -o "$ZIP" install/SHA256SUMS install/manifest.txt -d "$TMP" >/dev/null 2>&1
[ -f "$TMP/install/SHA256SUMS" ] || abort "this zip has no SHA256SUMS"
sum_of() { grep " \*\?$1\$" "$TMP/install/SHA256SUMS" | awk '{print $1}'; }

BOOT_SHA=$(sum_of boot.img)
ROOTFS_SHA=$(sum_of rootfs.img)
[ -n "$BOOT_SHA" ] && [ -n "$ROOTFS_SHA" ] || abort "SHA256SUMS is missing an entry"

ui_print " "
ui_print "Build:"
while read -r line; do ui_print "  $line"; done < "$TMP/install/manifest.txt"
ui_print " "

# --- 3. /data has to be mounted, unencrypted and roomy ---------------------
mount /data >/dev/null 2>&1
if [ ! -d /data ] || ! grep -q " /data " /proc/mounts; then
    abort "/data is not mounted.
       On a phone still carrying stock Android, /data is encrypted and TWRP
       cannot write to it. Wipe > Format Data (type 'yes') first, then run
       this zip again. That erases your Android data - back it up first."
fi
if [ -d /data/system/users ] || [ -e /data/system/packages.xml ]; then
    abort "/data still holds an Android installation.
       Wipe > Format Data first. Installing over it leaves Android's
       encryption policy in place and Ubuntu Touch will not boot."
fi

# The zip entry is compressed; what has to fit on /data is the expanded image,
# whose size the manifest records.
free_kb=$(df /data | tail -1 | awk '{print $4}')
need_kb=$(( $(grep '^rootfs_bytes=' "$TMP/install/manifest.txt" | cut -d= -f2) / 1024 ))
if [ "$free_kb" -lt $((need_kb + 262144)) ]; then
    abort "/data has ${free_kb}K free, the rootfs needs ${need_kb}K plus headroom."
fi
ui_print "/data: ${free_kb}K free, need ${need_kb}K"

# --- 4. boot image ----------------------------------------------------------
ui_print " "
ui_print "Writing the boot image..."
unzip -o "$ZIP" install/boot.img -d "$TMP" >/dev/null 2>&1 || abort "no install/boot.img in this zip"
got=$(sha256sum "$TMP/install/boot.img" | awk '{print $1}')
[ "$got" = "$BOOT_SHA" ] || abort "boot.img in the zip is corrupt
       expected $BOOT_SHA
       got      $got"

img_bytes=$(stat -c%s "$TMP/install/boot.img" 2>/dev/null || wc -c < "$TMP/install/boot.img")
[ "$img_bytes" -le "$BOOT_PARTITION_BYTES" ] || abort "boot.img is larger than the partition"

if [ -n "$DRYRUN" ]; then
    ui_print "  (dry run: not writing $BOOT_DEV)"
else
    dd if="$TMP/install/boot.img" of="$BOOT_DEV" bs=1048576 >/dev/null 2>&1 \
        || abort "dd to $BOOT_DEV failed"
    sync
    # Read back exactly as many bytes as were written. dd does not fail on a
    # short write to a block device, so this is the only thing that proves it.
    back=$(dd if="$BOOT_DEV" bs=512 count=$(( (img_bytes + 511) / 512 )) 2>/dev/null \
           | head -c "$img_bytes" | sha256sum | awk '{print $1}')
    [ "$back" = "$BOOT_SHA" ] || abort "boot partition read-back does NOT match.
       DO NOT REBOOT. Reflash a known-good boot image first."
    ui_print "  boot partition verified ($BOOT_SHA)"
fi
rm -f "$TMP/install/boot.img"

# --- 5. rootfs --------------------------------------------------------------
ui_print " "
ui_print "Writing the rootfs (this takes a few minutes)..."
if [ -n "$DRYRUN" ]; then
    ui_print "  (dry run: not writing $ROOTFS_TARGET)"
else
    rm -f "$ROOTFS_TARGET"
    unzip -p "$ZIP" install/rootfs.img.gz | gzip -dc > "$ROOTFS_TARGET" \
        || abort "could not write $ROOTFS_TARGET"
    sync
    ui_print "  hashing (a few more minutes)..."
    back=$(sha256sum "$ROOTFS_TARGET" | awk '{print $1}')
    [ "$back" = "$ROOTFS_SHA" ] || abort "rootfs.img on /data does NOT match.
       expected $ROOTFS_SHA
       got      $back
       Usually a full or failing /data. Format Data and try again."
    ui_print "  rootfs verified ($ROOTFS_SHA)"
fi

# --- 6. debug image: ask usb-moded for developer mode -----------------------
# /usr/libexec/force-adb, in the rootfs, honours a marker on userdata:
#   /userdata/.force-ssh  -> developer_mode
#   /userdata/.force-adb  -> charging_only_adb
# It is the supported way for a porter to force this, and it is needed because
# the phablet user has no password until the wizard runs, which otherwise makes
# force-adb turn ADB off.
VARIANT=$(grep '^variant=' "$TMP/install/manifest.txt" | cut -d= -f2)
if [ "$VARIANT" = "devel" ] && [ -z "$DRYRUN" ]; then
    : > /data/.force-ssh
    sync
    ui_print "  debug image: /userdata/.force-ssh written"
fi

rm -rf "$TMP"
sync

ui_print " "
ui_print "Done."
ui_print " "
ui_print "Reboot to System. First boot takes 2-5 minutes: the port"
ui_print "generates its Android-container overrides before the container"
ui_print "starts, and Ubuntu Touch then runs its own first-boot setup."
ui_print " "
if [ "$VARIANT" = "devel" ]; then
    ui_print "THIS IS THE DEBUG IMAGE."
    ui_print "  SSH is on, root's password is 1234, adb host-key"
    ui_print "  verification is off. Over USB:"
    ui_print "      ssh root@10.15.19.82      or      adb shell"
    ui_print "  Anyone who can reach this phone can be root on it."
    ui_print " "
fi
ui_print "If it does not reach the wizard, plug in USB and telnet to"
ui_print "192.168.2.15 - the Halium initramfs runs a debug shell there."
ui_print " "
exit 0
