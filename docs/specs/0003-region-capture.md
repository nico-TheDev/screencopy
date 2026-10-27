# 0003. Region capture: frozen snapshot, drag a box, hand off the pixels

**Date**: 2026-10-27
**Status**: Proposed

## Summary

Pressing the hotkey takes a still picture of every screen, dims them, and lets you drag a box on one of them. When you let go, the app cuts that box out of the still picture and hands it onward, then closes the overlay. Escape or a right click cancels. If screen recording is not allowed, you see the existing permission window instead. Working from a still picture means moving video or the dimming can never change what gets read.

## Context

Feature 3 in `docs/scope/scope.md`. Spec [0001](0001-native-mac-stack/index.md) fixed the stack (macOS 14, Swift 6, AppKit overlay, ScreenCaptureKit, `KeyboardShortcuts`) and the scaffold already has: the hotkey (`HotkeyController`, default Option+Shift+2, currently only logs), the permission check (`ScreenRecordingPermission`), a status window, and the protocols `ScreenCapturing` and `ClipboardWriting` in `ScreencopyKit`. Text recognition and the clipboard arrive in feature 4.

Forces:
- The app is not the frontmost app when the hotkey fires, and must work over full screen apps and every Space.
- AppKit coordinates start bottom left, ScreenCaptureKit and `CGImage` start top left. Retina screens have more pixels than points. These two mismatches are the usual source of off by some pixels captures.
- Dimming drawn by the overlay must not end up in the result.
- Only one person uses this, on this Mac. Privacy rule from 0001: images stay in memory, never on disk, never logged.

## Requirements

**User stories**:
- As the owner, I want to press a hotkey and drag a box over any part of any display so that I can pick exactly the text I want.
- As the owner, I want to back out with Escape or a right click so that a wrong press costs nothing.
- As the owner, I want a clear message when screen recording is not allowed so that I know what to switch on.

**Acceptance criteria**:
- **AC-1**: Pressing the hotkey from any app, including a full screen app on another Space, shows a dimmed still picture of every display within about half a second. The app you were in stays the active app (when Screencopy's own window was in front, that window stays in front).
- **AC-2**: You can drag a box in any direction. The box is clear (undimmed) and stays inside the display where the drag started; the other displays stay dimmed and ignore the mouse until the capture ends.
- **AC-3**: Letting go of the mouse captures at once: the overlay closes on every display and exactly one image is handed to the next step.
- **AC-4**: The handed over image is cut from the still picture at native pixels. Its size equals the box size in points times the display scale (within 1 pixel), and its content matches what was under the box, on a Retina display, a non Retina display, and a second display.
- **AC-5**: The dimming, size readout, hint text, crosshair, and any Screencopy window never appear in the image.
- **AC-6**: Escape cancels. The overlay closes and nothing is handed over.
- **AC-7**: A right click cancels the same way.
- **AC-8**: A click without dragging, or a box smaller than 4 points on either side, is ignored. The overlay stays open.
- **AC-9**: Pressing the hotkey while a capture is in progress does nothing. There is never a second overlay.
- **AC-10**: While selecting you see a crosshair cursor, a live readout of the box size in pixels (width × height px), and a hint line ("Drag to select, Esc to cancel") that fades after about 3 seconds.
- **AC-11**: If screen recording is not allowed, no overlay appears. The existing status window comes forward with a line saying capture needs permission, plus its Ask and Open System Settings buttons. The hotkey itself never triggers the system prompt.
- **AC-12**: If the screen snapshot fails or takes longer than 2 seconds although permission looks granted, no overlay appears and the status window comes forward with a plain line saying what failed and the Open System Settings button.
- **AC-13**: If the Space or the display layout changes, the overlay panel loses key status, another app is activated, the displays sleep, or the session locks while the overlay is open, the capture cancels and the overlay closes. The screen is never left dimmed.
- **AC-14**: No network is used. Snapshots and the cropped image are never written to disk or logged, and are released when the capture ends.

## Options considered

### Option 1: Frozen snapshot overlay, crop from the snapshot (chosen)
Capture each display once on the hotkey, show those pictures in the overlay, crop the result from the same picture.
**Pros**: what you see is exactly what you get; overlay dimming cannot leak into the result; moving content (video, tooltips) holds still while you aim; one capture call per display.
**Cons**: short delay before the overlay appears; needs permission before the overlay can show; a full display image is held in memory during the drag.

### Option 2: Live dimmed overlay, capture after release
Show a dim window over the live screen, then call ScreenCaptureKit with the chosen rectangle.
**Pros**: overlay appears instantly; no full display images in memory.
**Cons**: the screen can change between aiming and grabbing; the dim window has to be excluded from the capture; the capture call happens after the overlay closes, so there is a visible flicker risk and a timing race.

### Option 3: Call the system `screencapture -i` tool
**Pros**: almost no code.
**Cons**: writes a file, cannot be styled or wired to an in memory handoff, and conflicts with the "nothing on disk" rule.

## Decision

**Chosen option**: Option 1: Frozen snapshot overlay, crop from the snapshot.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`). It is a SwiftUI skill; the overlay itself is AppKit, so use it only for the hint and readout views if they are built in SwiftUI.

Decisions inside this option, with the pick, why, and the runner up:
- **Release captures at once, no adjust step** (your pick). Runner up: handles plus Enter, an extra step on every use.
- **One display per drag** (your pick). Runner up: a box spanning displays, which needs stitched images for a rare case.
- **Cancel with Escape and right click only** (your pick). A repeat hotkey press is ignored, a tiny click is ignored.
- **The package owns the math and the capture, the app owns the windows.** Crop math and the snapshot call live in `ScreencopyKit` so they can be tested without a screen. The overlay, state machine, and permission window live in the app target. Runner up: everything in the app target, which loses the tests.
- **Selection view is flipped** (`isFlipped = true`), so a drag is already in top left points relative to the display. That matches `CGImage` and ScreenCaptureKit and removes the bottom left conversion.
- **Scale comes from the snapshot, not from `NSScreen`.** `scale = snapshot.width / displayWidthInPoints`. Runner up: `NSScreen.backingScaleFactor`, which can disagree with the actual capture size on scaled modes.
- **Overlay window**: one borderless `NSPanel` per display, `.nonactivatingPanel` style, override `canBecomeKey` to true, level above the menu bar, `collectionBehavior` of join all Spaces plus full screen auxiliary. Non activating keeps the source app active (AC-1) and still lets the panel receive Escape. Runner up: activate Screencopy while selecting, which steals focus from the app you copy from. If Escape does not arrive in practice, fall back to activating the app and note it here.
- **`NSWindow.sharingType = .none` is not used.** The overlay shows a picture that was already taken, so hiding it from other apps adds little, and a forum report says it does not hold in full screen (unverified).
- **Snapshot excludes Screencopy's own windows** through the content filter, so the status window or a debug preview left on screen never appears in a capture.
- **Snapshot all displays together** with a task group. If any one fails, the whole capture fails (AC-12), so the user never sees an overlay that covers only some displays.
- **Finding displays and the app to exclude.** Fetch `SCShareableContent` once per hotkey press (it can take 100 to 300 ms, so it counts against the half second in AC-1). Match each `SCDisplay.displayID` to an `NSScreen` through `NSScreenNumber`; match Screencopy by `Bundle.main.bundleIdentifier` among the running apps in that content. If the two display lists differ (a mirrored or just attached display), fail the whole capture. The snapshot function takes the displays, not one ID.
- **Display size in points comes from `NSScreen.frame.size`.** The panel, the clamping, and the scale all use it. If it disagrees with the size ScreenCaptureKit reports for that display, treat it as a capture failure.
- **No Escape during `snapshotting`.** No panel exists yet, so the key would go to the app in front, and listening globally needs Accessibility permission. Each start gets a number; results with a stale number are thrown away (the ScreenCaptureKit call does not stop when its task is cancelled). A 2 second timeout routes to the AC-12 failure path.
- **Panel settings.** Level `.screenSaver`; `hidesOnDeactivate = false`; `acceptsFirstMouse` returns true so the first click starts a drag; override `constrainFrameRect` so the menu bar cannot push the panel down; every panel handles `rightMouseDown`. The panel on the display under the mouse becomes the key window and handles Escape (`cancelOperation` and `keyDown`).
- **Crosshair** through an `NSTrackingArea` with `.activeAlways` and `.cursorUpdate`, and `NSCursor.crosshair.set()` again on every mouse move, because cursor rects only work in the active app. If it still flickers, activate the app while selecting and note it here.
- **Drawing.** Each snapshot is the panel view's layer contents; one dim sublayer with a hole for the box does the dimming, so no custom `draw(_:)` is needed. Readout sits 12 points below and right of the cursor and flips inward near display edges; the hint is centered near the top of the display under the mouse, fades from about 2.5 to 3 seconds, and neither shows during `snapshotting`.
- **Cancel sources while selecting**: `NSWindow.didResignKeyNotification` on the key panel, `NSWorkspace.didActivateApplicationNotification`, `NSWorkspace.screensDidSleepNotification`, `NSWorkspace.sessionDidResignActiveNotification`, `NSWorkspace.activeSpaceDidChangeNotification`, and `NSApplication.didChangeScreenParametersNotification`. Ignore the Space change event for about 200 ms after the panels appear, because showing a panel over a full screen app can fire it.
- **Display lock.** The first mouse down picks the active display; any mouse up releases the lock (so after an ignored tiny click the next drag can start on any display). The 4 point minimum applies only on mouse up; the box still draws while dragging.
- **Handoff is one closure**, `onCaptured: (CGImage) -> Void`, set by the app delegate. In release builds feature 3 only logs the pixel size. In debug builds it opens a small window showing the image so you can check accuracy by eye. Feature 4 replaces the closure with recognition.

## Feature design

**Data model sketch**: none. No storage. Values only: `CaptureRegion` (already exists: `displayID`, `rect` in points, top left, display local) and the in memory `CGImage` snapshots.

**State transitions** (`CaptureCoordinator`, main actor):
`idle` → (hotkey, permission ok) → `snapshotting` → (all snapshots in) → `selecting` → (mouse up with a valid box) → `finishing` → `idle`.
`snapshotting` → `idle` on snapshot failure or the 2 second timeout (status window shown). `selecting` → `idle` on Escape, right click, or any cancel source listed in the Decision. `finishing`: close every panel, crop, call `onCaptured` on the main actor, then `idle`. A hotkey press in any state except `idle` is ignored. Each start carries a number; a snapshot result whose number is stale is discarded.

**API surface** (internal; no network):
| Function | Where | Key inputs | Key outputs | Key errors |
|---|---|---|---|---|
| `ScreenCapturing.snapshot(displays:)` (replaces `capture(_ region:)`) | `ScreencopyCapture` | `[CGDirectDisplayID]` | one full display `CGImage` per display at native pixels, own app windows and cursor excluded | `ScreencopyError.permissionDenied` (also for ScreenCaptureKit "user declined"), `.captureFailed` |
| `RegionCropper.pixelRect(for:scale:bounds:)` | `ScreencopyCore` (pure) | selection `CGRect` (points), scale, image bounds in pixels | integral pixel rect: floor min edges, ceil max edges, clamp | empty rect when nothing remains |
| `RegionCropper.crop(_:selection:displaySize:)` | `ScreencopyCore` (pure) | snapshot `CGImage`, selection `CGRect` (points, top left, display local), display size in points | cropped `CGImage` drawn into a fresh bitmap, so it does not keep the whole snapshot alive | returns `nil` if the pixel rect is empty |
| `CaptureCoordinator.start()` | app target | none | drives overlay and calls `onCaptured` | shows status window on permission or snapshot failure |
| `AppDelegate.showPermissionStatus(message:)` | app target | optional one line text | brings the window forward | none |

The `ScreenCapturing` protocol is in Core today with `capture(_ region:)`. Changing it is part of this feature; nothing else uses it yet.

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Snapshot | which displays to capture | `NSScreen.screens`, each display ID from `NSScreen.deviceDescription["NSScreenNumber"]`, matched to `SCShareableContent` displays (confirm the match at build) |
| Snapshot | which app to exclude | Screencopy, found by `Bundle.main.bundleIdentifier` in the `SCShareableContent` running apps |
| Snapshot | pixel size of the image | the display's size in points times its pixel scale, set on the capture configuration (API names to confirm at build) |
| Overlay | position and size of each panel | that display's `NSScreen.frame` |
| Overlay | display size in points | `NSScreen.frame.size` |
| Drag | selection rect | mouse points in the flipped selection view, so top left and display local; clamped to the view bounds (AC-2) |
| Crop | scale factor | `snapshot.width / displaySizeInPoints.width` |
| Crop | pixel rect | `RegionCropper.pixelRect`: selection × scale, min edges floored, max edges ceiled, clamped to the image |
| Readout | width × height in pixels | the same `pixelRect` function, updated while dragging |
| Hint | which display shows it | the display under the mouse when capture starts |
| Permission gate | granted or not | `ScreenRecordingPermission.status()`; never `request()` from the hotkey |
| Status window | message text | fixed strings in the app: one for missing permission, one for snapshot failure. The permission one says to quit and reopen the app after allowing it, because the check can stay false until relaunch |
| Status window | current permission | re-read from `ScreenRecordingPermission.status()` every time the window is shown |
| Minimum box | 4 points | decided here |

**Key invariants**:
- The overlay never exists while the state is `idle`; every path to `idle` closes every panel.
- Only the display where the mouse went down gets a box; its selection never leaves that display's bounds.
- A hotkey press while not `idle` changes nothing.
- The image handed over is always a crop of the snapshot taken at hotkey time, never a second capture.
- Snapshots are dropped when the state returns to `idle`: panels closed, layer contents cleared, references released.

**Security model**: single user, local app, no accounts. Screen content is sensitive: kept in memory only, never logged (log sizes and state changes only), never written to disk. No network APIs imported. Not sandboxed (spec 0001), so the only gate is the macOS Screen Recording permission, which the app respects and never tries to bypass.

**Configuration required**: none. The hotkey name `.capture` already exists. No new entitlements or Info.plist keys expected; check at build whether the system asks for a usage description string.

**Critical test scenarios**:
- Happy path: hotkey in another app, drag a box, release; the debug preview shows exactly the boxed pixels at native size, verifies AC-1, AC-3, AC-4, AC-5.
- Retina and second display: repeat on each display, compare image pixel size to box × scale, verifies AC-2, AC-4.
- Crop math (unit tests, no screen): scale 1 and 2, box at the origin, box touching the far edge, box dragged backwards (right to left, bottom to top), box clamped to the display, empty rect returns `nil`, verifies AC-2, AC-4.
- Cancel and ignore: Escape, right click, tiny click, box under 4 points, second hotkey press, verifies AC-6 to AC-9.
- Failure: revoke permission in System Settings, then press the hotkey; no overlay, status window with the message, verifies AC-11. Plug or unplug a display, or switch Space, with the overlay open; it closes, verifies AC-13. Use `tccutil reset ScreenCapture com.norbertoignacio.screencopy` to repeat the permission test.
- Privacy: search the source for networking and file writing of images; confirm nothing is logged but sizes, verifies AC-14.

## Build plan

Ordered by Skateboard: a thin but complete use first (one display, hotkey to cropped image), then the rest.

1. **Core crop math.** Add `RegionCropper` (`pixelRect` and `crop`, crop drawn into a fresh bitmap) and Swift Testing cases for scale, offsets, backwards drags, clamping, rounding within 1 pixel, empty. Satisfies **AC-4**.
2. **Snapshot call.** Replace `ScreenCapturing.capture(_ region:)` with `snapshot(displays:)`. Implement it in `ScreencopyCapture` with ScreenCaptureKit (one `SCShareableContent` fetch per call), native pixels, own app and cursor excluded. Map failures, including "user declined", to `ScreencopyError`. Add a fake for tests. Satisfies **AC-4**, **AC-5**, **AC-12**.
3. **Coordinator and one display thread.** `CaptureCoordinator` with the states above; hotkey handler calls it; permission gate; snapshot the main display; one flipped selection view in a non activating panel draws the snapshot, dim, and clear box; mouse up crops and calls `onCaptured`; debug preview window. Satisfies **AC-1**, **AC-2**, **AC-3**, **AC-4**, **AC-11**.
4. **Cancel and ignore rules.** Escape, right click, tiny box, repeat hotkey. Satisfies **AC-6**, **AC-7**, **AC-8**, **AC-9**.
5. **All displays.** One snapshot and one panel per display, first mouse down picks the active display, others ignore the mouse. Satisfies **AC-1**, **AC-2**, **AC-4**.
6. **Overlay polish and reach.** Crosshair cursor, pixel readout, fading hint, window level and Space behavior for full screen apps. Satisfies **AC-1**, **AC-10**.
7. **Messages and failure paths.** Make `PermissionStatusView` re-read the permission on every show, add an error state with a message and the Open System Settings button, add `showPermissionStatus(message:)`, route snapshot failure and the 2 second timeout, discard stale capture numbers. Satisfies **AC-11**, **AC-12**.
8. **Robustness and privacy.** Wire every cancel source from the Decision (including the 200 ms Space change grace period); release snapshots and clear layer contents on every exit path; confirm no logging of content. Satisfies **AC-13**, **AC-14**.
9. **Manual verify pass** with the test scenarios above. Satisfies **AC-1** to **AC-14**.

## Consequences

**Positive**:
- The result always matches what you saw; no race between aiming and grabbing.
- The risky math is a pure function with tests; windows stay thin.
- The handoff closure gives feature 4 one clean place to plug in.

**Negative / tradeoffs**:
- A short delay before the overlay, and a full display image per display in memory during the drag (about 230 MB for a 6K plus a 5K display).
- Changing `ScreenCapturing` is a breaking change inside the package; only the scaffold used it.
- Non activating panels receiving Escape is expected to work but is not confirmed; there is a fallback.
- Boxes cannot span two displays.

**Neutral**:
- macOS may ask you to re approve screen recording periodically (reported for macOS 15, current behavior unconfirmed). The permission message should mention it if seen.
- A debug only preview window is extra code removed or kept behind `#if DEBUG` after feature 4.

## Follow-up

- [ ] Verify against Apple docs at build time (the research pass could not load these pages): the async form of `SCScreenshotManager.captureImage`, how to set native pixel size (`pointPixelScale`, `SCDisplay.width`, `SCStreamConfiguration.width`), `SCContentFilter(display:excludingApplications:exceptingWindows:)`, `showsCursor`, that `NSScreenNumber` equals `SCDisplay.displayID`, and whether `SCDisplay.frame` uses a top left origin.
- [ ] Verify the right window level and `collectionBehavior` for covering the menu bar and full screen apps on every Space, that a non activating panel receives Escape, and that showing the overlay over a full screen app on another Space does not cancel itself.
- [ ] Confirm the current macOS re approval behavior and whether `CGRequestScreenCaptureAccess` needs a relaunch (already listed in spec 0001).
- [ ] Feature 4 replaces the `onCaptured` closure and decides the success and "no text found" signals.
- [ ] Hint text and status window messages are English only for now; language choice is feature 6.

## References

**Project sources**:
- Spec [0001](0001-native-mac-stack/index.md): stack, privacy rules, and the open items for this feature
- `docs/scope/scope.md`, feature 3 "Done when"
- Existing code: `HotkeyController`, `ScreenRecordingPermission`, `PermissionStatusView`, `ScreencopyCore/Protocols.swift`

**Practices & standards**:
- Capture once, crop from the same frame (removes timing races)
- Take pixel scale from the actual image, not from a display property
- Pure functions for geometry, so they are testable without a screen

**Links** (web verified only):
- SCScreenshotManager, available from macOS 14.0: https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager.md
- Monthly screen recording prompt in macOS Sequoia betas (press report): https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/ and https://tidbits.com/2024/08/19/apple-reduces-excessive-sequoia-permission-requests-shifts-to-monthly
- Forum report that `sharingType = .none` did not block capture in full screen (not an Apple statement): https://developer.apple.com/forums/thread/69290
