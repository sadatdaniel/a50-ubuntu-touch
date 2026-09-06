#!/bin/bash
# Turn a built rootfs into a DEBUG image: SSH on, root password set, adb
# unlocked, USB networking up on boot.
#
# This exists because a port that nobody can log into cannot be debugged by
# anybody but its author. A release image is the published UBports rootfs and
# has SSH off, so the first thing a tester can report is "it did not boot", with
# nothing to attach.
#
# WHY NOT UPSTREAM'S VERSION. prepare-fake-ota.sh's devel-flashable path writes
# /etc/init/ssh.override and /etc/init/usb-tethering.conf - upstart jobs. This
# rootfs is 26.04 and has no /etc/init at all, so those files would be created,
# committed, released, and silently ignored. Everything below is the systemd
# equivalent, checked against the units that are actually in the image.
#
# The password is deliberately weak and deliberately documented. Anyone who can
# reach this phone over USB can be root on it. That is the point of a debug
# image, and it is why it ships as a separate download that says so in its name.
#
#   ./scripts/release/add-devel-access.sh /path/to/mounted/rootfs
set -euo pipefail

ROOT="${1:?usage: $0 <mounted rootfs>}"
PASSWORD="${A50_DEVEL_PASSWORD:-1234}"
[ -d "$ROOT/etc/systemd/system" ] || { echo "E: $ROOT is not a rootfs" >&2; exit 1; }

# --- 1. sshd: allow a password, and allow root ------------------------------
# /etc/ssh/sshd_config.d/50-lxc-android-config.conf sets PasswordAuthentication
# no. A higher-numbered drop-in wins; the shipped file is left alone so it is
# obvious what was overridden.
cat > "$ROOT/etc/ssh/sshd_config.d/99-a50-devel.conf" <<'EOF'
# a50 DEBUG image only. Overrides 50-lxc-android-config.conf, which turns
# password authentication off. Delete this file to get a normal image back.
PasswordAuthentication yes
PermitRootLogin yes
PermitEmptyPasswords no
EOF

# --- 2. root password -------------------------------------------------------
# Fixed salt so two builds of the same commit produce the same /etc/shadow.
# sha512crypt is arch-independent, which matters: the build host is x86 and
# cannot run the target's own passwd.
HASH=$(openssl passwd -6 -salt a50develimg "$PASSWORD")
sed -i "s|^root:[^:]*:|root:${HASH}:|" "$ROOT/etc/shadow"
grep -q "^root:\$6\$" "$ROOT/etc/shadow" || { echo "E: root password not set" >&2; exit 1; }

# --- 3. enable sshd at boot -------------------------------------------------
# ssh.service, not ssh.socket: lxc-android-config-disable-ssh-socket.service is
# enabled in this rootfs and disables the socket on first boot by design. Going
# through the service leaves that alone instead of fighting it.
ln -sf /usr/lib/systemd/system/ssh.service \
    "$ROOT/etc/systemd/system/multi-user.target.wants/ssh.service"

# --- 4. USB networking ------------------------------------------------------
# /usr/bin/usb-tethering brings up RNDIS with LOCAL_IP=10.15.19.82 - that is
# where the phone answers, and it is the address in every one of this port's
# docs because it is the script's own default, not a local choice.
ln -sf /usr/lib/systemd/system/usb-tethering.service \
    "$ROOT/etc/systemd/system/multi-user.target.wants/usb-tethering.service"

# --- 5. adb without host-key verification -----------------------------------
sed -i 's/^ADBD_SECURE=.*/ADBD_SECURE=0/' "$ROOT/etc/default/adbd"
grep -q '^ADBD_SECURE=0' "$ROOT/etc/default/adbd" || { echo "E: ADBD_SECURE not set" >&2; exit 1; }

# --- 6. say what this is, on the image itself -------------------------------
cat > "$ROOT/etc/a50-image-variant" <<EOF
variant=devel
ssh=on
ssh_user=root
ssh_password=$PASSWORD
usb_ip=10.15.19.82
adbd_secure=0
EOF

cat > "$ROOT/etc/motd" <<EOF

  ####  A50 Ubuntu Touch - DEBUG IMAGE  ####

  SSH is on and root's password is "$PASSWORD". ADB host-key verification is
  off. Anyone who can reach this phone can be root on it.

  This is for porting and bug reports. Do not carry it around as a daily
  phone, and do not put a SIM you care about in it.

  Reach it over USB:   ssh root@10.15.19.82        (or: adb shell)
  What is going on:    journalctl -b -p warning
                       lxc-attach -n android -- /system/bin/logcat -d -b all
  Report at:           https://github.com/sadatdaniel/a50-ubuntu-touch/issues

EOF

echo "I: devel access enabled - ssh.service, usb-tethering.service, root/$PASSWORD, ADBD_SECURE=0"
