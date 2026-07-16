# Upstream Sources

## Grok Build

- Repository: https://github.com/xai-org/grok-build
- Pinned commit: `b189869b7755d2b482969acf6c92da3ecfeffd36`
- License: Apache-2.0
- Role: authoritative agent/runtime and ACP reference.

The iOS app does not claim that the unmodified desktop binary can execute inside an iOS process. The native client uses the same product boundary exposed by Grok Build's Agent Client Protocol. A future Rust static-library target must preserve the upstream license and notices and replace process, PTY, sandbox, and host-filesystem dependencies with iOS adapters.

## Litter

- Repository: https://github.com/dnakov/litter
- Verified commit: `abee3ace684204a3cbc4ea1e0e903b9f31518dac`
- License: GPL-3.0 with additional app-store distribution permission
- Role: reference implementation for persistent iSH fakefs execution on iOS.

No Litter source is copied into this Apache/MIT-compatible tree. Linking or copying Litter requires relicensing this combined work under GPL-3.0-compatible terms or obtaining a separate license.
