# On-device Grok Engine

The iOS product runs the official Grok Build CLI inside an embedded iSH kernel:

1. CI cross-compiles pinned `xai-org/grok-build` source for `aarch64-unknown-linux-musl`.
2. The executable is added to the Alpine rootfs as `/usr/local/bin/grok`.
3. A minimal Litter-derived iSH bridge boots the persistent fakefs.
4. Swift invokes `grok --prompt ... --format json --session ...` and parses JSONL events.
5. Permission and tool events are surfaced as native SwiftUI controls.

The aarch64 probe intentionally runs independently from the IPA workflow until the upstream portability patches are proven and vendored.
