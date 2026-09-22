#!/bin/sh
set -eu
B=/userdata/a50-session20-aa12
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")"
P="$B/apparmor-probe.profile"
printf 'allowed\n' > "$B/probe-allowed"
printf 'forbidden\n' > "$B/probe-denied"
cat > "$P" <<'PROFILE'
#include <tunables/global>
profile a50-aa12-enforcement-probe {
  #include <abstractions/base>
  /usr/bin/cat rix,
  /userdata/a50-session20-aa12/probe-allowed r,
  deny /userdata/a50-session20-aa12/probe-denied r,
}
PROFILE
apparmor_parser -a "$P"
trap 'apparmor_parser -R "$P"' EXIT
test "$(aa-exec -p a50-aa12-enforcement-probe -- /usr/bin/cat "$B/probe-allowed")" = allowed
if aa-exec -p a50-aa12-enforcement-probe -- /usr/bin/cat "$B/probe-denied" > "$B/denied-result" 2> "$B/denied-error"; then
    echo 'ERROR: forbidden read succeeded'; exit 1
fi
test ! -s "$B/denied-result"
grep -q 'Permission denied' "$B/denied-error"
echo 'AppArmor enforcement verified: permitted read succeeded; forbidden read denied'
