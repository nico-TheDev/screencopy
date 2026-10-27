# 0004. Recognize the selected text and copy it to the clipboard

**Date**: 2026-10-27
**Status**: Proposed

## Summary

After you drag a box, the app reads the text in it on your Mac and puts that text on the clipboard, one line per line you see on screen. A small notice appears inside the box with a sound: "Copied 42 characters", "No text found", or "Couldn't read the selection". If nothing was found or reading failed, your clipboard is left exactly as it was. The recognition language is detected automatically for now, and feature 6 adds a picker later.

## Context

Release 1 turns a screen region into clipboard text. Capture (feature 3) hands over an image held in memory. This step has to turn Vision's list of text observations into one string, decide when a result counts as empty, protect the clipboard from being overwritten with nothing, and tell the user what happened without a notification permission.

Fixed by spec [0001](0001-native-mac-stack/index.md): Vision `VNRecognizeTextRequest` (accurate level) behind the `TextRecognizer` protocol, plain text on `NSPasteboard.general`, no network, nothing written to disk or logged (image or text), Swift 6 strict concurrency. This spec was asked to settle the points 0001 left open for feature 4: line ordering, how success and "no text found" are shown, and blocked content.

Dependency: feature 3 has no spec yet. This spec assumes it delivers a `CGImage` plus the `CaptureRegion` it came from (display id and rect in points), and that the region can be mapped to a screen position for the notice. If feature 3 changes that contract, update this spec.

## Requirements

**User stories**:
- As the user, I want the text I drag over to land on the clipboard so I can paste it into any app.
- As the user, I want a clear signal when nothing was copied so I do not paste stale clipboard content by mistake.

**Acceptance criteria** (the contract, each independently checkable):
- **AC-1**: A capture of printed text pastes into another app with the right characters, one line per visible line, in top to bottom reading order. Boxes Vision splits on one visual line are joined with a space. Only the whole string is trimmed (leading and trailing whitespace and newlines). Language correction stays on, so Vision may correct tokens; that is accepted.
- **AC-2**: Recognition runs on this Mac only. No networking API is imported or called.
- **AC-3**: If the text is empty after trimming whitespace, the clipboard is not written and the notice says "No text found". There is no confidence cutoff.
- **AC-4**: If recognition throws, the clipboard is not written and the notice says "Couldn't read the selection". This wording differs from AC-3 so a failure is not mistaken for blank pixels.
- **AC-5**: A selection with width or height under 8 points is treated as "No text found" without running Vision.
- **AC-6**: On success the notice says "Copied N characters" ("Copied 1 character" when N is 1), where N is `String.count` of the text written, plain digits, and never shows the copied text.
- **AC-7**: The notice (about 36 points tall, width fitted to its text) appears centered inside the captured region. If the region is smaller than the notice plus 8 points each side, it appears top center of that display, 48 points below the top of `visibleFrame`. It shows for 1.5 seconds, fades over 0.25 seconds, does not take focus, ignores the mouse, and a new notice replaces the current one.
- **AC-13**: If recognition is still running 300 ms after the drag ends, a "Reading..." notice (no sound) appears and is replaced by the final outcome.
- **AC-14**: The notice is excluded from screen capture (`sharingType = .none`), and is dismissed when the capture hotkey is pressed, so it is never read back as text.
- **AC-8**: Copied plays one soft system sound. No text found and failure play a different one. Sounds are always on in Release 1.
- **AC-9**: Pressing the capture hotkey cancels a recognition still running. A cancelled result never writes the clipboard or shows a notice.
- **AC-10**: The recognition language is detected automatically (`languages == nil`).
- **AC-11**: The captured image and the text are never written to disk or logged. Logs hold outcome and error type only.
- **AC-12**: Content that macOS blocks from capture (such as protected video) never crashes. The outcome is "No text found" (black pixels) or "Couldn't read the selection" (capture error); both leave the clipboard untouched.
- **AC-15**: A capture error before recognition (`captureFailed`) shows "Couldn't read the selection". `permissionDenied` shows no notice and goes to the permission flow decided in feature 3. A clipboard write that returns false is reported as "Couldn't read the selection".

## Options considered

### Option 1: Vision lines in reading order, trimmed, notice plus sound near the region

Join Vision's lines top to bottom with newlines, trim the ends, write only when non empty, and show an on screen notice with a system sound.

**Pros**:
- Predictable and easy to test. No guessing about paragraphs.
- No notification permission, nothing private shown in the notice.

**Cons**:
- Wrapped paragraphs paste with hard line breaks.
- A custom notice window is more code than a system notification.

### Option 2: Reflow into paragraphs and fix hyphenated wraps

Merge lines that look like one paragraph and rejoin split words.

**Pros**:
- Nicer for prose from articles and PDFs.

**Cons**:
- Wrong on code, tables, and lists, and it silently changes what Vision saw. Harder to verify.

### Option 3: Notification Center banner

Use a system notification for the outcome.

**Pros**:
- Less UI code.

**Cons**:
- Needs a permission, and Focus modes can hide it, so a silent failure looks like success.

## Decision

**Chosen option**: Option 1: Vision lines in reading order, trimmed, notice plus sound near the region

Recognize with Vision on a background task, order and trim the result, write the clipboard only on non empty text, and report one of three outcomes with a notice and a sound.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`)

**RECOMMEND calls made here**:
- Ordering: group observations into rows when their vertical overlap is at least 50% of the shorter box's height. Sort rows top first (Vision's origin is bottom left, so descending `boundingBox.midY`), sort inside a row by `minX` and join with one space, join rows with `\n`. Vision's result order is not guaranteed to be reading order, and one visual line can come back as several boxes. Runner up: trust Vision's order, rejected because it is undocumented.
- Concurrency: `TextCapturePipeline` is a `@MainActor final class` with `start(image:region:)`. It holds the current task and an incrementing generation number; a run writes the clipboard or notifies only if its generation is still current, checked on the main actor right before the write. `ClipboardWriting` and `OutcomeNotifying` are `@MainActor`; only `TextRecognizer` runs off the main actor. If the compiler warns about `CGImage` crossing actors, wrap it in a small `@unchecked Sendable` box.
- Clipboard: `clearContents()` then `setString(_, forType: .string)`, no concealed or transient markers. `write` returns `Bool`.
- Notice panel: `NSPanel` with `.borderless` and `.nonactivatingPanel`, level `.statusBar`, `canJoinAllSpaces`, `fullScreenAuxiliary`, `ignoresMouseEvents`, cannot become key, does not hide on deactivate, `sharingType = .none`. Also excluded from the capture filter if feature 3 uses one.
- Logging: `Logger` with the bundle id as subsystem, category `capture`, fields are the outcome case and error case only.
- VoiceOver: `NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])`.
- Sounds: `NSSound(named: "Pop")` for copied, `NSSound(named: "Funk")` for no text and failure. Built in, no audio files. Runner up: `Tink` and `Basso`, rejected as Basso is harsh.
- Accessibility: post an `NSAccessibility` announcement with the notice text so VoiceOver users hear the outcome. Runner up: visual only, rejected since the notice is the only feedback.
- Cancellation: the pipeline holds the current task and cancels it on a new capture, and checks `Task.isCancelled` after recognition and before writing. Vision itself cannot be interrupted, so the stale result is discarded rather than stopped.

## Feature design

**Data model sketch**: No stored data. Transient values only, all in memory:
- `CaptureRegion` (exists in `ScreencopyCore`): display id, rect in points.
- `ExtractedText` (exists): `text: String`, empty check trims whitespace.
- `CaptureOutcome` (new, `ScreencopyCore`): `.copied(characterCount: Int)`, `.noText`, `.failed`. A separate `.reading` state drives the "Reading..." notice.
- `CaptureRegion.rect` is display local, top left origin, in points (to be confirmed in the feature 3 spec). The notice presenter finds the `NSScreen` whose `deviceDescription["NSScreenNumber"]` equals `displayID` and flips Y into Cocoa's global bottom left coordinates.
- Update the `ExtractedText` doc comment: `text` is already trimmed, so empty means nothing was found.

**State transitions**: one capture is `recognizing`, then one of `copied`, `noText`, `failed`, or `cancelled` (silent). A new capture moves the old one to `cancelled`.

**API surface** (in process functions, no network):
| Function | Inputs | Outputs | Auth | Key errors |
|---|---|---|---|---|
| `TextCapturePipeline.start(image, region)` and `cancelCurrent()` (main actor; `cancelCurrent` is called on hotkey press) | `CGImage`, `CaptureRegion`; recognizer, clipboard writer, and outcome notifier injected | `CaptureOutcome` (sent to the notifier) | none | recognizer throws, or clipboard `write` returns false, mapped to `.failed` |
| `TextRecognizer.recognize(image, languages)` (exists) | `CGImage`, `languages: [String]?` | `ExtractedText`, ordered and trimmed | none | throws `ScreencopyError.recognitionFailed` |
| `ClipboardWriting.write(text)` (exists, becomes `@MainActor`, returns `Bool`) | `String` | success flag | none | false means failed |
| `OutcomeNotifying.show(outcome, region)` (new protocol, AppKit implementation in the app target) | `CaptureOutcome`, `CaptureRegion` | none | none | none |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Copy | The string written to the clipboard | Vision observations, sorted per the ordering rule, joined with `\n`, trimmed |
| Notice | N in "Copied N characters" | `String.count` of the trimmed string written |
| Notice | "Reading..." trigger | 300 ms timer started when recognition begins |
| Notice | Sizes and timings | Decided in AC-7 |
| Notice | Where it appears | `CaptureRegion` (display id plus rect), mapped to a screen frame by the notice presenter; coordinate rules decided in the feature 3 spec |
| Notice | Which wording | `CaptureOutcome` case |
| Recognition | Languages | Fixed `nil` (detect) in Release 1; the setting arrives with feature 6 |
| Recognition | Minimum size | Constant 8 points, `rect.width < 8 || rect.height < 8`, measured in points before scaling |

**Key invariants**:
- The clipboard is written only when the trimmed text is non empty and the run was not cancelled.
- A cancelled run produces no clipboard write and no notice.
- Image and text never touch disk or logs. The image is released after recognition.
- Vision objects stay inside the recognizer. Only plain values cross actors.

**Security model**: Single user, local app. The notice never shows copied text, so a screenshot of it leaks nothing. Captured content may be sensitive, so nothing is persisted here. No compliance scope.

**Configuration required**: none.

**Critical test scenarios**:
- Happy path: fixture image of three printed lines goes through real Vision, text comes back in order with newlines, trimmed, verifies **AC-1**.
- Failure case: fake recognizer throws, clipboard fake is untouched and outcome is `.failed`, verifies **AC-4**.
- Empty: fake returns whitespace only, clipboard untouched, outcome `.noText`, verifies **AC-3**.
- Tiny region: 4 by 4 point region never calls the recognizer, verifies **AC-5**.
- Overlap: start a slow fake, start a second capture, only the second writes the clipboard, verifies **AC-9**.
- Character count: "e" plus a combining accent counts as 1, a single character says "Copied 1 character", verifies **AC-6**.
- Clipboard fake returns false: outcome is `.failed`, verifies **AC-15**.
- Slow fake recognizer: the "Reading..." state fires after 300 ms, verifies **AC-13**.
- Manual in `/check verify`: real paste into another app, notice position and sound, no notice focus steal, a network check by searching the source, protected video gives "No text found", verifies **AC-2**, **AC-7**, **AC-8**, **AC-11**, **AC-12**.

## Build plan

Approach is Skateboard: the thinnest whole first, with feature 3 supplying the image. Until feature 3 lands, drive the pipeline from a test or a debug entry point.

1. Make `VisionTextRecognizer` sort observations by reading order and trim the result. Add fixture image tests against real Vision, satisfies **AC-1**, **AC-10**.
2. Add `CaptureOutcome`, `OutcomeNotifying`, and the main actor `TextCapturePipeline` to `ScreencopyCore` with the empty rule, minimum size rule, error mapping, character count, generation counter cancel, and the 300 ms "Reading..." state. Make `ClipboardWriting` and `OutcomeNotifying` `@MainActor`, `write` returning `Bool`. Test with the three fakes, satisfies **AC-3**, **AC-4**, **AC-5**, **AC-6**, **AC-9**, **AC-11**, **AC-13**, **AC-15**.
3. Add the real `ClipboardWriter` over `NSPasteboard.general` (plain string, clear then set) in the app target, satisfies **AC-1**, **AC-3**, **AC-15**.
4. Add the notice presenter in the app target: the panel described in the decision, centered on the region with the top center fallback, timings, the two sounds, the VoiceOver announcement, and `sharingType = .none`, satisfies **AC-7**, **AC-8**, **AC-14**.
5. Wire the pipeline to the capture result from feature 3 (cancel on hotkey press, dismiss the notice) and confirm no networking import exists, satisfies **AC-2**, **AC-9**, **AC-12**, **AC-14**, **AC-15**.

## Consequences

**Positive**:
- Output is predictable and matches what is on screen.
- The clipboard is never replaced by an empty or failed result.
- The pipeline is testable with fakes, with no screen permission.

**Negative / tradeoffs**:
- Wrapped paragraphs paste with hard line breaks, and hyphenated wraps stay split.
- Vision cannot be interrupted, so a cancelled recognition still burns CPU until it finishes.
- Automatic language detection can be slightly less accurate than a fixed language until feature 6.
- A custom notice window must be kept off the capture (feature 3 settles how the overlay is excluded) and off the key window.

**Neutral**:
- Sounds are always on until the settings window (feature 5) offers a mute.
- History (feature 7) will need the text from this pipeline. It must be added there without changing the no disk rule here.

## Follow-up

- [ ] Feature 3 spec must confirm the `CGImage` plus `CaptureRegion` handoff and how a region maps to a screen frame for the notice.
- [ ] Check on a real screen that the 8 by 8 point minimum does not block a valid single character selection.
- [ ] `swiftui-expert-skill` conventions are not yet in root `AGENTS.md`; `/audit` should record them (already noted in spec 0001).

## Rationale

The reasons are short. A faithful per line copy is the only layout that is right for text, code, and lists alike, and your own choice was to trim only. A custom notice avoids a permission and the Focus mode problem, and showing a count instead of the text keeps captured content out of any screenshot of the notice. The distinct failure wording protects against the main risk of this feature, pasting stale clipboard content believing it was fresh.
