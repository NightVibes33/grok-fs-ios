#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 BASE_FS_TAR_GZ GROK_BINARY OUTPUT_FS_TAR_GZ" >&2
  exit 64
fi

base_archive=$1
grok_binary=$2
output_archive=$3
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

test -s "$base_archive"
test -s "$grok_binary"
tar -xzf "$base_archive" -C "$work"
test -d "$work/fs/data/usr/local/bin"
install -m 0755 "$grok_binary" "$work/fs/data/usr/local/bin/grok"
test -x "$work/fs/data/usr/local/bin/grok"

tar -czf "$output_archive" -C "$work" fs
tar -tzf "$output_archive" | grep -qx 'fs/data/usr/local/bin/grok'
