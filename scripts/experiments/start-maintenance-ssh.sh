#!/bin/sh
# Runtime-only standard OpenSSH instance, reachable through authorized USB.
set -eu
test "$(id -u)" = 0
key=${1:-/home/phablet/a50-key.pub}
test -s "$key"
test "$(awk '{print $1}' "$key")" = ssh-ed25519
if systemctl is-active --quiet a50-maintenance-ssh.service; then
    echo "Temporary SSH is already active; stop it before changing its key." >&2
    exit 1
fi
ssh-keygen -lf "$key"
install -d -m 0700 /run/a50-maintenance-ssh
printf 'from="127.0.0.1",restrict %s\n' "$(cat "$key")" > /run/a50-maintenance-ssh/authorized_keys
chmod 0600 /run/a50-maintenance-ssh/authorized_keys
cat > /run/a50-maintenance-ssh/sshd_config <<'CONFIG'
Port 2222
ListenAddress 127.0.0.1
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile /run/a50-maintenance-ssh/sshd.pid
AuthorizedKeysFile /run/a50-maintenance-ssh/authorized_keys
AllowUsers root
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTTY no
LogLevel VERBOSE
CONFIG
test -s /etc/ssh/ssh_host_ed25519_key
install -d -m 0755 /run/sshd
/usr/sbin/sshd -t -f /run/a50-maintenance-ssh/sshd_config
systemd-run --collect --unit=a50-maintenance-ssh --property=Type=simple \
    /usr/sbin/sshd -D -e -f /run/a50-maintenance-ssh/sshd_config
systemctl is-active --quiet a50-maintenance-ssh.service
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo 'Temporary USB-only key authentication ready; reboot removes it.'
