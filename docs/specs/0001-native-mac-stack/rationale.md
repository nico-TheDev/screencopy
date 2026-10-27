# 0001 Rationale: native Mac stack

## Context

Screencopy is a Mac app that works like the Windows Snipping Tool, except it puts the text it finds in your selection on the clipboard instead of an image. It is for one person, and the scope rules out sending anything off the Mac.

The work is three hard jobs, all tied to the operating system: a global hotkey that works from any app, a drag overlay that covers every display, and the screen recording permission. Text recognition has to run on device. The app must stay running, and the scope wants it small enough to live in the menu bar later.

Forces: one developer, one user, no scale target, Skateboard build approach (smallest whole you would use, then grow). A Windows version is deferred and optional. Macs older than macOS 14 do not matter; you chose 14 as the floor. Not deciding now would stall every other feature, since capture, recognition, and the menu bar all depend on this stack.

## Options considered

### Option 1: Native Mac app (Swift 6, SwiftUI shell, AppKit overlay)

Use Apple's frameworks directly for capture, recognition, and permissions, with SwiftUI for the menu bar and settings and AppKit for the overlay.

**Pros**:
- The three hard jobs are first class Apple APIs, with no bridge code.
- Smallest memory and install size, fastest start, correct permission behavior.
- Logic in a local Swift package is testable without the app.

**Cons**:
- Mac only; a Windows version means a rewrite.
- You work in Xcode and Swift, with some AppKit knowledge needed for the overlay.

### Option 2: Tauri (Rust core plus web UI)

A small cross platform shell with a web front end.

**Pros**:
- Small compared with Electron, and a path to Windows.

**Cons**:
- Screen capture, permission handling, and Apple text recognition still need Swift or Objective C glue, so you maintain two languages.
- A drag overlay across displays is harder to get right in a web view.

### Option 3: Electron

Chromium and Node with a web UI.

**Pros**:
- Easiest if you know web tech; a path to Windows.

**Cons**:
- Heavy for a tiny menu bar tool, and the screen recording permission is tied to the large Electron host.
- OCR still needs a native module or a bundled engine such as Tesseract.

### Option 4: Flutter or Kotlin Multiplatform

Cross platform UI with native plugins.

**Pros**:
- One UI codebase for a possible Windows version.

**Cons**:
- The overlay, capture, and recognition are all native plugins anyway, so the shared UI covers the smallest part of this app.

## Rationale

Option 1 wins on the forces above. Every hard job is an OS feature, so any cross platform option still ends in native code for the parts that matter, while adding a second toolchain for a one person project. The only thing the others buy is an easier Windows version, and the scope explicitly defers that as "only if you ever want it". Paying a permanent complexity cost now for a feature you may never build fails the day 1 test (can we ship it?) and the simple beats clever test.

The sub choices follow the same logic. Vision for recognition because it is on device, adds no dependency, and works on macOS 14; it sits behind a `TextRecognizer` protocol because the newer Swift API needs macOS 15 and the older one's future is unconfirmed. ScreenCaptureKit because it is the current capture path and the older call is reported to raise extra permission alerts. `KeyboardShortcuts` because Release 2 needs a user changeable hotkey with a recorder, which the raw Carbon call would make you build yourself. Not sandboxed with an Apple Development signature because the screen recording permission is tied to the app's signature, and a stable one avoids re granting it after each rebuild.

Swift 6 strict concurrency was recommended and chosen because three kinds of work run on different threads; the cost is some extra annotation while learning the APIs. The logic lives in a package so the part most worth testing (the flow from region to clipboard) runs from the command line.

The Release 1 Dock icon choice is mine: a menu bar agent with no menu bar icon would have no way to quit. The menu bar and history store choices are left to their own specs because they are not needed until later and I could not verify the menu bar API details.

## Landscape evidence (researched 2026-10-27, cheapest model, 5 searches and 8 page fetches)

- **Recognition**: `RecognizeTextRequest` (Swift native, macOS 15.0+) has accurate and fast levels, automatic language detection, a priority ordered language list, a runtime list of supported languages, and async `perform(on:)`. `VNRecognizeTextRequest` (macOS 10.15+) still works and, per the cross check, also has language detection and a supported language list since macOS 13; deprecation not confirmed. WWDC25 session 272 adds `RecognizeDocumentsRequest` (paragraphs and tables), judged overkill for a clipboard tool. Tesseract (Apache 2.0, 100+ languages) is only worth it for a language Vision lacks.
- **Capture**: `SCScreenshotManager` is macOS 14+. Apple's Sequoia beta notes say older capture calls trigger alerts and should move to ScreenCaptureKit. Permission calls and re approval behavior are unverified.
- **Hotkey**: `KeyboardShortcuts` v3.x, SwiftPM only, minimum macOS 10.15, includes a SwiftUI recorder with `UserDefaults` persistence. `HotKey` is simpler with no recorder, and its maintenance was not confirmed.
- **Menu bar and login**: `MenuBarExtra` (macOS 13+) and `SMAppService` (macOS 13+) from memory only.
- **Not researched**: current Swift and Xcode versions, lint and format tools, signing details beyond the basics.
- **Agent skills found** (listing only, quality unchecked): SwiftUI, Swift concurrency, Swift Testing, Vision (listing says iOS). None for ScreenCaptureKit or `KeyboardShortcuts`.

## References

**Project sources**:
- `docs/scope/scope.md`: the Skateboard approach, the on device only decision, the macOS 14 floor you chose in this session, and the Deferred list.
- Installed skill `swiftui-expert-skill` (`.agents/skills/swiftui-expert-skill/`).

**Practices & standards**:
- Monolith first; one process for one user.
- Put logic behind a protocol when the underlying vendor API is moving (the `TextRecognizer` protocol).
- Keep sensitive data out of logs.

**Links** (web verified in the landscape check):
- RecognizeTextRequest: https://developer.apple.com/documentation/vision/recognizetextrequest.md
- WWDC25 session 272, Vision documents: https://developer.apple.com/videos/play/wwdc2025/272/
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
- Tesseract: https://github.com/tesseract-ocr/tesseract
- Not verified, cited by name only: Apple's macOS Sequoia beta note on screen recording re approval.
