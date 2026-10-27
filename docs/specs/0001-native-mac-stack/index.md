# 0001. Build Screencopy as a native Mac app in Swift

**Date**: 2026-10-27
**Status**: In Progress

## Summary

Screencopy will be a native Mac app written in Swift. It uses Apple's own tools for the three hard jobs: ScreenCaptureKit to grab the pixels, the Vision framework to read the text on your Mac, and a small hotkey package to listen for the shortcut. Everything runs on your machine with no network. The app is built as one small program, with the real logic in a separate Swift package so it can be tested without launching the app.

## Decision

**Chosen option**: Option 1: Native Mac app (Swift 6, SwiftUI shell, AppKit overlay)

Build one process, one user, no server, on Apple's frameworks, with the logic in a local Swift package and a thin Xcode app target on top.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`)

This spec covers the scaffold feature in `docs/scope/scope.md` (#1 Stack & architecture). The scaffold is done when the project launches on your Mac and can ask for and receive the screen recording permission. `/develop` derives the scaffold steps from the stack below.

## Proposed stack

| Layer | Choice | Reason |
|---|---|---|
| App type | Native macOS app, one process, runs only on this Mac | Screen capture, text recognition, and permissions are all Apple APIs, so no bridge code is needed. |
| Minimum OS | macOS 14 Sonoma | Gives the modern screenshot API and covers any Mac still in use. Your choice. |
| Language | Swift 6 language mode, strict concurrency | Capture, recognition, and UI run on different threads, so the compiler should catch races. |
| UI | SwiftUI for the menu bar and settings, AppKit for the capture overlay | A borderless, multi display, always on top drag window is AppKit territory; SwiftUI is weak there. |
| Screen capture | ScreenCaptureKit, `SCScreenshotManager.captureImage(contentFilter:configuration:)` | The macOS 14 call. The simpler `captureImage(in:)` needs macOS 15.2, so it is not used. The older `CGWindowListCreateImage` is reported to trigger extra alerts. |
| Text recognition | Apple Vision, `VNRecognizeTextRequest`, accurate level | On device, no dependency, works on macOS 14, and detects language since macOS 13. Wrapped behind a `TextRecognizer` protocol (see the code sketch) so the newer `RecognizeTextRequest` (macOS 15 only) can replace it later. |
| Global hotkey | `KeyboardShortcuts` package (sindresorhus), SwiftPM, app target only. Default ⌥⇧2, declared in one place | Ships a recorder view and saved setting, which Release 2 needs. Uses Carbon inside, which needs no Accessibility permission. ⌘⇧3, ⌘⇧4, ⌘⇧5 belong to macOS screenshots. |
| Clipboard | `NSPasteboard.general`, plain text only | Built in. Written only when recognized text is not empty. |
| Settings storage | `UserDefaults` (through `KeyboardShortcuts` and `@AppStorage`) | A few small values, no need for more. |
| History storage | Store decided in the capture history spec (feature 7); it stores recognized text only, never images | Not needed until Release 4. Text only keeps the "no image on disk" rule simple. |
| Menu bar | Decided in the menu bar spec (feature 5) | Release 1 has no menu bar icon. SwiftUI `MenuBarExtra` versus `NSStatusItem` is unverified here. |
| Start at login | Deferred (`SMAppService` is the expected API) | Out of the current build pass in the scope. |
| Project layout | Xcode app project plus a local Swift package | Thin app target for UI, package for logic so tests run from the command line. |
| Tests | Swift Testing; XCTest only where UI tests need it | Apple's modern framework. |
| Logging | `os.Logger`, events and errors only | Built in. Recognized text and images are never logged. |
| Signing and identity | Bundle id `com.norbertoignacio.screencopy`. Not sandboxed, Hardened Runtime on with no exceptions, signed with your Apple Development certificate and team (never "Sign to Run Locally"), run locally | The screen recording approval is tied to the bundle id and the signature, so changing either means granting it again. An ad hoc signature changes every build. No paid notarization for personal use. |
| Entitlements and Info.plist | No entitlements. `LSMinimumSystemVersion` 14.0, package `platforms: [.macOS(.v14)]`, `swift-tools-version:6.0` | Unsandboxed capture needs no entitlement. |
| App lifecycle | SwiftUI `App` with an AppKit app delegate and an empty `Settings` scene. Do not quit when the last window closes. Clicking the Dock icon shows the permission status | A SwiftUI `App` must have a scene. Feature 5 later switches to a menu bar only app at runtime with `NSApp.setActivationPolicy(.accessory)`. |
| Network | None | Nothing in the app opens a connection. |
| Hosting, database, auth, jobs | None | One user, one Mac, nothing to host. |
| Lint and format | Decided in feature 2 (`/audit`, `/develop tooling`) | Chosen from the real scaffolded project. |

### Shape of the code (a sketch for the scaffold, not a build plan)

```
Screencopy.xcodeproj           thin app target: app entry, capture overlay (AppKit),
                               permission messaging, later menu bar and settings (SwiftUI)
ScreencopyKit/ (local package)
  Core         shared types (CaptureRegion, RecognizedText, errors) and one protocol per
               OS boundary: ScreenCapturing, TextRecognizer, ClipboardWriting
  Capture      ScreenCaptureKit wrapper (ScreenCapturing), screen recording permission check
  Recognition  VisionTextRecognizer (TextRecognizer)
  *Tests       Swift Testing targets, using fakes for the three protocols
```

`TextRecognizer` is `recognize(_ image: CGImage, languages: [String]?) async throws -> RecognizedText`, where `nil` means detect the language. The real capture and the real clipboard are covered by a manual or `/check verify` step, since they need screen permission.

Flow for one capture: hotkey, permission check, overlay on every display, user drags a rectangle (display plus rectangle in points), `Capture` returns a `CGImage` held in memory, `Recognition` returns text or nothing, `ClipboardWriter` writes it only if there is text, otherwise the user gets a "no text found" signal.

### Constraints the build must honor

- **No network.** No networking APIs are imported or used. `/check verify` confirms it by searching the source.
- **Nothing private is kept.** The captured image stays in memory and is released after recognition. Image and text are never written to disk or logged before the history spec (feature 7) decides otherwise.
- **The clipboard is only overwritten on success.** An empty or unreadable selection leaves it untouched.
- **Permission state is checked before showing the overlay**, and a missing permission shows a message that points to the right System Settings pane.
- **Concurrency.** UI types stay on the main actor. Capture and recognition run off the main thread and hand back plain values. Vision's synchronous calls are wrapped in a background async function that returns a plain `String`; Vision objects never cross actors.
- **Dock icon in Release 1.** Run as a normal app until the menu bar icon exists (feature 5), then switch to a menu bar only app at runtime. Without a Dock icon and without a menu bar icon, the app could not be quit.
- **History is text only.** Images are never stored.

## Consequences

**Positive**:
- Smallest and fastest result, with the best fit for Mac permission and window behavior.
- No server, account, or recurring cost. Privacy follows from the design: nothing leaves the Mac.
- Logic in a package is testable without launching the app.

**Negative / tradeoffs**:
- The Windows version in the scope's Deferred list would be a rewrite, not a port. Your call, since the scope marks it "only if you ever want it".
- Vision's `VNRecognizeTextRequest` may be on a deprecation path (unconfirmed). The newer API needs macOS 15, so a later swap either raises the minimum OS or keeps both paths.
- Accuracy on messy handwriting is whatever Vision gives. A cloud engine is already ruled out.
- Several API details were not verified against Apple docs (see Follow-up). Treat them as things to check in the first hour of the scaffold.
- Not sandboxed means no Mac App Store, and the app has full user level access. Fine for a personal tool.

**Neutral**:
- On recent macOS versions the system may re prompt for screen recording approval periodically. Reported in 2024 beta notes, current behavior unconfirmed.
- `KeyboardShortcuts` and the Carbon calls under it are a dependency on code Apple has not touched in years.

## Follow-up

- [ ] At scaffold, verify the permission calls `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess` against Apple docs; the research could not load those pages. Reset the permission for testing with `tccutil reset ScreenCapture com.norbertoignacio.screencopy`.
- [ ] Region capture spec (feature 3) must settle: the coordinate space and Retina scaling (AppKit is bottom left across the desktop, ScreenCaptureKit is top left per display), limiting a drag to the display where it started, keeping the overlay's own dimming out of the capture (exclude the app from the filter, or capture a frozen frame first), the overlay window rules so Escape works (a panel that can become key), and the permission flow including the "grant, then relaunch" quirk with an Open Settings link.
- [ ] Recognize and copy spec (feature 4) must settle: turning Vision's per line results into ordered text with line breaks, how success and "no text found" are shown (a floating notice and sound, not a system notification), and that content blocked from capture (such as protected video) shows up as "no text found".
- [ ] Menu bar spec (feature 5): hotkey clash detection is likely best effort, so say so in its "Done when" line.
- [ ] Confirm whether `VNRecognizeTextRequest` is deprecated and what the current Swift version and Xcode are.
- [ ] Check whether the current macOS version re prompts for screen recording approval, and note the behavior for users in the permission message.
- [ ] Pick your Apple Development team in Xcode at scaffold time (the bundle id is fixed above).
- [ ] Menu bar spec (feature 5): decide `MenuBarExtra` versus `NSStatusItem`; capture history spec (feature 7): decide the store.
- [ ] `swiftui-expert-skill` conventions are not yet in root `AGENTS.md` (none exists). `/audit` should record the skill, and the Swift, Swift Testing, and Vision conventions, once the scaffold exists.
- [ ] Optional skills you did not pick but may want later: `swift-concurrency` (`avdlee/swift-concurrency-agent-skill`), `swift-testing-expert` (`avdlee/swift-testing-agent-skill`), `vision-framework` (`dpearson2699/swift-ios-skills`, check macOS applicability). No MCP server was chosen; the reported Apple Xcode MCP needs a recent Xcode and macOS and was not verified.

## Rationale

Reasoning and options: see [rationale.md](rationale.md).
