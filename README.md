# GrokFS iOS

GrokFS is a native SwiftUI iOS 26 coding agent powered by the official open-source Grok Build engine. Grok Build runs locally as a static AArch64-musl executable inside a persistent embedded iSH Alpine filesystem.

## Included Product

- Official `xai-org/grok-build` headless agent pinned to commit `b189869b7755d2b482969acf6c92da3ecfeffd36`.
- Daniel Nakov's `litter-ish` embedded kernel pinned to `c8e9dcb954963b0d9f359b3ad9da871f19b28652`.
- Persistent Alpine fakefs with `/root`, `/tmp`, `/mnt`, and `/root/.grok`.
- Native SwiftUI chat, Grok thoughts/tool event cards, conversation persistence, rename, delete, and search.
- Stable UUIDs shared between native conversations and Grok Build sessions.
- Native fakefs browser/editor with file and folder creation, save, recursive delete, and refresh.
- Local shell mode and direct xAI API fallback.
- xAI API key storage in iOS Keychain.
- Runtime diagnostics showing iSH architecture and Grok Build version.
- Source/license notices bundled in the application.
- Unsigned real-device IPA built and inspected on GitHub `macos-26` runners.

## Runtime

At build time, CI downloads the pinned engine release and verifies SHA-256:

```text
cd937a9297fe7e73ed61941d0bcf7db7bc84409e4d38bf09232b4b40c231ead9
```

The engine is installed into the bundled rootfs as:

```text
/usr/local/bin/grok
```

The app invokes Grok Build in headless streaming-JSON mode with a persistent session UUID. Grok's own tools execute against the same `/root` that the native file browser displays.

## Authentication

Open Settings, enter an xAI API key, and select **Grok Build**. The key is stored in Keychain and passed to the embedded process as `XAI_API_KEY`.

## Unsigned IPA

The workflow builds for `generic/platform=iOS`, archives without signing, creates `Payload/GrokFS.app`, and uploads `GrokFS-unsigned.ipa`. It also opens the IPA and verifies that the nested rootfs contains `/usr/local/bin/grok`.

The IPA must be signed with an appropriate development, enterprise, or sideloading certificate before installation on a stock device.

## Build From Source

```sh
brew install xcodegen meson ninja
rustup target add aarch64-apple-ios aarch64-unknown-linux-musl
cargo build \
  --manifest-path engine/ish-bridge/Cargo.toml \
  --target aarch64-apple-ios \
  --release
mkdir -p apps/ios/GeneratedRuntime/ios-device
cp engine/ish-bridge/target/aarch64-apple-ios/release/libgrokfs_ish_bridge.a \
  apps/ios/GeneratedRuntime/ios-device/
scripts/prepare-grok-rootfs.sh \
  apps/ios/Sources/GrokFS/Resources/fs.tar.gz \
  /path/to/grok-aarch64-musl \
  /tmp/fs-with-grok.tar.gz
mv /tmp/fs-with-grok.tar.gz apps/ios/Sources/GrokFS/Resources/fs.tar.gz
cd apps/ios
xcodegen generate
xcodebuild build \
  -project GrokFS.xcodeproj \
  -scheme GrokFS \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

## License

The combined application is GPL-3.0-or-later because it links the GPL-licensed iSH embedding runtime. Grok Build's first-party source remains Apache-2.0. See `NOTICE`, `ThirdParty/UPSTREAMS.md`, and the license files bundled under application resources.
