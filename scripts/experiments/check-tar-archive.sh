#!/bin/sh
# Safe nested-path archive round trip; use the installed or candidate tar.
set -eu
archive_tool=${1:-/usr/bin/tar}
probe_dir=$(mktemp -d /tmp/a50-tar-probe.XXXXXX)
trap 'rm -rf "$probe_dir"' EXIT HUP INT TERM
mkdir -p "$probe_dir/input/sub" "$probe_dir/output"
printf 'A50 nested archive test\n' > "$probe_dir/input/sub/file"
"$archive_tool" -cf "$probe_dir/data.tar" -C "$probe_dir/input" sub/file
"$archive_tool" -xf "$probe_dir/data.tar" -C "$probe_dir/output"
cmp "$probe_dir/input/sub/file" "$probe_dir/output/sub/file"
echo 'PASS: nested archive create/extract preserves the file'
