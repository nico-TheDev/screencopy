# Screencopy

A Mac menu bar app that works like the Snipping Tool, but puts the text it finds in your screenshot on the clipboard. One user, one Mac, everything on device.

## Stack

- **Language / Runtime**: Swift 6 language mode with strict concurrency, macOS 14 minimum
- **Framework**: SwiftUI for the menu bar and settings, AppKit for the capture overlay
- **Key dependencies**: ScreenCaptureKit (capture), Vision (text recognition), `KeyboardShortcuts` package (hotkey, app target only), Swift Testing
- **Package manager**: Swift Package Manager. Xcode app project `Screencopy.xcodeproj` plus the local package `ScreencopyKit/`
- Source of truth: [docs/specs/0001-native-mac-stack/index.md](docs/specs/0001-native-mac-stack/index.md)

## Build approach

Skateboard: ship the smallest complete product you would actually use, then grow it release by release.

## Commands

```bash
# Style and warnings check (lint, then package build with warnings as errors)
scripts/check

# Format all Swift files in place
scripts/check format

# Package tests
cd ScreencopyKit && swift test

# Enable the pre commit hook (once per clone)
git config core.hooksPath .githooks
```

The Xcode app target is built and run from Xcode (scheme `Screencopy`). `scripts/check` does not build it.

## Specs

Stored in `docs/specs/`. Format: `docs/specs/NNNN-title.md`, or a folder with `index.md` for larger decisions. The feature scope is `docs/scope/scope.md`.

## Rules

- **Layout**: the app target stays thin (UI, AppKit overlay, permission messages). Logic lives in `ScreencopyKit`, one protocol per OS boundary (`ScreenCapturing`, `TextRecognizer`, `ClipboardWriting`), so tests run with fakes and without screen permission.
- **Concurrency**: UI types stay on the main actor. Capture and recognition run off the main thread and hand back plain values. Vision objects never cross actors.
- **No network, nothing private kept**: no networking APIs. The captured image is never written to disk. Text is never logged and is stored only by capture history. Logs hold events and error types only (`os.Logger`).
- **Clipboard**: written only when the recognized text is not empty and the run was not cancelled.
- **Banned in app and package code**: force unwrap (`!`), `try!`, and `Type!` declarations. Tests may use them. Anywhere else needs a `// swift-format-ignore: NeverForceUnwrap` comment with a reason.
- **Style**: 4 space indent, 120 column lines, enforced by `swift-format` (`.swift-format`). Warnings fail in `scripts/check` only.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, `style:`).
- **Tests**: Swift Testing for package logic, with fakes. Real capture, clipboard, and permission steps are covered by `/check verify`.
- **Signing**: bundle id `com.norbertoignacio.screencopy`, not sandboxed, Hardened Runtime, signed with your Apple Development team. Changing either means granting screen recording again.
- **Accessibility**: UI follows a WCAG AA baseline, with VoiceOver labels on controls and notices.

## Tooling

- Format and lint: Apple `swift-format` (`xcrun swift-format`), decided in [spec 0002](docs/specs/0002-swift-standards-and-tooling.md).
- Pre commit: `.githooks/pre-commit` formats and lints staged Swift files.
- CI: none for now. `scripts/check` and the hook are the gate.

## Git

- integration: on
- branch prefix: feat/
- commit: per-milestone

## Agent skills

- [swiftui-expert-skill](.agents/skills/swiftui-expert-skill/): `avdlee/swiftui-agent-skill`, SwiftUI state, layout, performance, and macOS API conventions.

Declined: extra Agent Skills and MCP servers (spec 0002), `swift-concurrency` and `swift-testing-expert` still open.

## Context files

<!-- Nested AGENTS.md files are listed here as they are created -->

_Drafted by /audit from the repo, worth a quick human pass. Edit freely: once a line stops matching this draft, later runs treat it as curated and will flag rather than overwrite it._
