#!/bin/sh
set -eu

GROK_REPO="${GROK_REPO:-https://github.com/xai-org/grok-build.git}"
GROK_COMMIT="${GROK_COMMIT:-b189869b7755d2b482969acf6c92da3ecfeffd36}"
checkout="${TMPDIR:-/tmp}/grok-build-source"

rm -rf "$checkout"
git clone --filter=blob:none --no-checkout "$GROK_REPO" "$checkout"
git -C "$checkout" checkout "$GROK_COMMIT" -- LICENSE README.md crates/codegen/xai-acp-lib
test -f "$checkout/LICENSE"
test -f "$checkout/crates/codegen/xai-acp-lib/src/lib.rs"
test "$(git -C "$checkout" rev-parse HEAD)" = "$GROK_COMMIT"
