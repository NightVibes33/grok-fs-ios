# GrokFS iOS

GrokFS is a native SwiftUI coding chat client for iOS 26 with a persistent app-owned fake filesystem rooted at `/root`. It builds an unsigned real-device IPA on GitHub's `macos-26` runners.

The project tracks the official open-source [xai-org/grok-build](https://github.com/xai-org/grok-build) agent and ACP surface. The currently shippable on-device runtime uses xAI's chat-completions API and a deterministic fakefs shell. The source boundary is designed for a later Rust static-library adapter; the desktop CLI itself cannot simply be spawned by a sandboxed iOS app.

## Product

- Native three-column SwiftUI workspace on iPad and adaptive navigation on iPhone.
- Persistent chat sessions with selectable Grok API or local-shell runtime.
- xAI-compatible chat completions with endpoint and model configuration.
- API key stored in the iOS Keychain.
- Persistent fake filesystem with `/root`, `/tmp`, and `/mnt`.
- File browser, text editor, create-folder, write, and remove operations.
- Shell commands for `pwd`, `ls`, `cat`, `mkdir`, `rm`, and `echo`.
- Apache-licensed Grok Build source pin and ACP integration contract.
- CI compile check, unit-test compile, unsigned archive, IPA structure check, and artifact upload.

## Setup

Open Settings in the app, select **Grok API**, enter an xAI API key, endpoint, and model. The default endpoint is `https://api.x.ai`; the client appends `/v1/chat/completions`.

Select **Local Shell** to run commands against the fake filesystem. Prefix commands with `$`, for example:

```text
$ ls /root
$ echo hello > /root/hello.txt
$ cat /root/hello.txt
```

## Unsigned IPA

CI packages `Payload/GrokFS.app` as `GrokFS-unsigned.ipa`. The IPA has no signature and must be signed with a valid development, enterprise, or sideloading certificate before installation on a stock device.

## Upstreams and Licensing

Official Grok Build is pinned in [ThirdParty/UPSTREAMS.md](ThirdParty/UPSTREAMS.md). Its first-party source is Apache-2.0.

Daniel Nakov's Litter is GPL-3.0 with an additional app-store permission. Its iSH bridge is useful reference work, but source is not copied here because doing so would change the combined project's licensing obligations. Exact Litter reuse requires a GPL release decision or a separate license.

## Development

```sh
brew install xcodegen
cd apps/ios
xcodegen generate
xcodebuild build \
  -project GrokFS.xcodeproj \
  -scheme GrokFS \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

The local iSH environment does not contain Apple's iPhoneOS SDK. GitHub Actions on `macos-26` is the authoritative compile and archive verifier.
