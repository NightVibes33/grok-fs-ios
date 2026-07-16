# Agent Notes

- Keep the public repo small. Do not vendor a full Alpine rootfs into Git.
- Do not copy GPL Litter source files unless the repo license is changed to a GPLv3-compatible license and attribution is updated.
- `apps/ios/project.yml` is the source of truth for the Xcode project.
- The app target is iOS 26.0 and must keep producing an unsigned real-device IPA on GitHub Actions `macos-26`.
- Prefer adding runtime implementations behind `AgentRuntime` instead of wiring provider-specific logic directly into SwiftUI views.
