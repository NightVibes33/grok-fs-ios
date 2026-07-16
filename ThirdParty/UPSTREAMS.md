# Upstream Sources

## Grok Build

- Repository: https://github.com/xai-org/grok-build
- Pinned commit: `b189869b7755d2b482969acf6c92da3ecfeffd36`
- License: Apache-2.0
- Build artifact: static AArch64-musl executable
- SHA-256: `cd937a9297fe7e73ed61941d0bcf7db7bc84409e4d38bf09232b4b40c231ead9`

The unmodified upstream composition binary is cross-compiled from source with default features disabled and installed in fakefs at `/usr/local/bin/grok`.

## litter-ish

- Repository: https://github.com/dnakov/litter-ish
- Pinned commit: `c8e9dcb954963b0d9f359b3ad9da871f19b28652`
- Release rootfs: `v0.1.2`
- License: GPL-3.0-or-later with `LICENSE.IOS`

The `ish-embed-host` crate is linked into the iOS application through `engine/ish-bridge`. The bridge boots the persistent AArch64 Alpine fakefs and executes commands and Grok Build sessions.

## Litter

- Repository: https://github.com/dnakov/litter
- Reference commit: `33dcf48728012cd4dae214570cca81ee95e3b341`
- License: GPL-3.0 with additional app-store distribution permission

Litter's persistent `IshFS` architecture, runtime setup, and native/fakefs separation informed the GrokFS integration. GrokFS uses Daniel's dedicated `litter-ish` embedding crate rather than copying Litter's Codex application layer.
