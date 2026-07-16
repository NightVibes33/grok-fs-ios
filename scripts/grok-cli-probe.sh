#!/bin/sh
set -eu

echo "== system =="
uname -a || true
cat /etc/os-release || true

echo "== toolchain =="
for bin in curl node npm bun grok; do
  if command -v "$bin" >/dev/null 2>&1; then
    printf '%s: %s\n' "$bin" "$(command -v "$bin")"
  else
    printf '%s: missing\n' "$bin"
  fi
done

echo "== grok =="
if command -v grok >/dev/null 2>&1; then
  grok --version || true
else
  echo "grok CLI not installed"
fi
