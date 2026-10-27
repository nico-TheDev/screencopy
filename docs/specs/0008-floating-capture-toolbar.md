# 0008. Floating capture toolbar with portion, screen, and window modes

**Date**: 2026-10-28
**Status**: In Progress

## Summary

When you press the capture hotkey, a small floating bar appears at the bottom of the screen you are using, like the macOS screenshot tool. It has three mode buttons (selected portion, entire screen, selected window), an Options menu, and a close button. Portion works as today (drag a box). Screen and window modes capture with one click on the target. The bar is built as a SwiftUI view inside a small non activating window (so the app you copy from stays active), and the window list comes from the system window list. It can be turned off in Settings, which brings back today's plain drag overlay.

## Context

Spec [0003](0003-region-capture/index.md) built the overlay: one dimmed panel per display, a drag to pick a box, and cancel rules. It has no buttons, no way to pick a whole screen or window, and no place for a setting that matters at capture time. Spec [0004](0004-recognize-and-copy-text.md) plays a sound on every result and left a mute to "settings, later". Spec [0005](0005-menu-bar-app-and-settings.md) adds the menu bar app and a Settings window with one row.

This feature adds the bar on top of that overlay, adds two new ways to choose pixels, and adds two small settings (sound, show the toolbar). It must not break the rules in 0003: the app you were in stays active, nothing Screencopy draws appears in the picture, and the screen is never left dimmed.

## Requirements

**User stories**:
- As the owner, I want a bar with mode buttons when I press the hotkey, so that I can pick what to read the way I do with the macOS screenshot tool.
- As the owner, I want to click a window or a screen to capture it, so that I do not have to drag a box over a whole window.
- As the owner, I want to mute the sounds and hide the bar when I do not want them.

**Acceptance criteria**:
- **AC-1**: With the toolbar on, the hotkey (or the menu item) shows the bar on the display under the mouse at that moment, together with the overlay and within the same half second as spec 0003 AC-1. The bar is about 300 points wide, centred horizontally, and sits 48 points above the bottom of that display's visible area (above the Dock) the first time.
- **AC-2**: The bar has, left to right: three mode buttons (selected portion, entire screen, selected window), a divider, an Options button, and a close button. Each button has a symbol and an accessibility label ("Capture selected portion", "Capture entire screen", "Capture selected window", "Options", "Close"). The active mode button looks selected and shows a tooltip with its key.
- **AC-3**: The bar opens in the mode you used last. On the first ever launch it opens in selected portion. Changing the mode saves it at once and it survives a restart.
- **AC-4**: You can drag the bar by its background. Its position is remembered per display and survives a restart. It always stays fully on the display (clamped). If the saved spot is no longer valid (display gone or smaller), it goes back to the default spot of AC-1.
- **AC-5**: Clicking, dragging, or releasing on the bar never starts a capture and never draws a box. The bar never appears in the captured image (spec 0003 AC-5 still holds).
- **AC-6**: Keys 1, 2, 3 switch to portion, screen, window. Escape or the close button cancels the capture. Both work without clicking the bar first. Keys are ignored while a drag is in progress.
- **AC-7**: Portion mode behaves exactly as spec 0003 AC-2 to AC-10: crosshair cursor, drag, size readout, tiny boxes ignored, one image handed over on release.
- **AC-8**: Screen mode: moving the mouse over a display lifts the dimming on that display (the others stay dimmed). One click on a display captures that whole display at native pixels and hands over one image. Size in pixels equals the display size in points times its scale (within 1 pixel).
- **AC-9**: Window mode: moving the mouse over a normal app window lifts the dimming over that window and draws a 2 point accent outline around it, clipped to that display. One click captures that area from the screen snapshot (what you see, including anything covering the window) and hands over one image. Only ordinary windows can be picked (window layer 0, on screen, at least 4 points on each side). Screencopy's own windows, the menu bar, the Dock, and the desktop are not pickable. Clicking where nothing is pickable does nothing and the overlay stays open.
- **AC-10**: If two windows overlap under the mouse, the one in front is picked. A window that spans two displays is captured only as far as the display where you clicked.
- **AC-11**: If the window list cannot be read, window mode still opens, nothing is highlighted, and clicks do nothing. Portion and screen modes are unaffected. The failure is logged without any window names.
- **AC-12**: The hint line changes with the mode ("Drag to select, Esc to cancel", "Click a screen to capture it", "Click a window to capture it") and fades after about 3 seconds as before. The cursor is the crosshair in portion mode and the arrow in the other two.
- **AC-13**: The Options menu has one item, "Play sounds", with a check mark. It defaults to on. Switching it off silences the Pop and Funk sounds from spec 0004 from the next result onward and survives a restart. Opening or using the menu does not cancel the capture.
- **AC-14**: The Settings window gets one checkbox, "Show the toolbar when I capture", on by default. When off, the hotkey shows the plain overlay of spec 0003 (no bar, portion mode only, today's behaviour) and 1, 2, 3 do nothing. Turning it on or off takes effect at the next capture.
- **AC-15**: Every cancel rule of spec 0003 AC-13 also closes the bar. Pressing the hotkey while a capture is open does nothing (0003 AC-9). After any end, neither the bar nor the overlay is left on screen.
- **AC-16**: The text pipeline of spec 0004 is unchanged. An image from any mode is recognized, copied, and announced the same way. No network is used, and no image or window name is written to disk or logged (sizes only).

## Options considered

### Option 1: SwiftUI bar inside a non activating `NSPanel`

The bar view is SwiftUI, hosted in a small borderless `NSPanel` that sits above the overlay panels on the active display. The panel cannot become key, so the overlay panel stays key and keeps getting Escape and the number keys.

**Pros**:
- Buttons, selected state, tooltips, and accessibility labels come almost free in SwiftUI.
- Fits the stack (SwiftUI app, AppKit where needed) and spec 0005.
- Clicking the bar does not activate Screencopy or cancel the capture.

**Cons**:
- Mouse handling and window levels have to be checked on the real system.
- The bar is not a keyboard focus target, so VoiceOver users reach modes through the number keys rather than by tabbing to the bar.

### Option 2: Draw the bar by hand in AppKit inside `SelectionView`

Custom layers and mouse tracking inside the existing overlay view.

**Pros**:
- One window per display, no level juggling.

**Cons**:
- Hand written buttons, hover, selected state, tooltips, and accessibility.
- The overlay view grows into a second job.

### Option 3: Launch the system `screencapture -i` and read the file

**Pros**:
- The real macOS UI.

**Cons**:
- Writes the picture to disk and cannot hold the bar, which breaks the "nothing is written to disk" rule of 0003 AC-14 and cannot show Screencopy's own options. Rejected.

## Decision

**Chosen option**: Option 1: SwiftUI bar inside a non activating `NSPanel`

Add a `ToolbarPanel` (hosting a SwiftUI `CaptureToolbarView`) shown by `CaptureCoordinator` on one display beside the overlay panels, add a `CaptureMode` to the package, and teach `SelectionView` to act on the mode.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`)

**RECOMMEND calls made here**:
- **Window list**: `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` read once per capture, in a new `ScreencopyCapture` type behind a `WindowListing` protocol (so tests use a fake). It returns windows front to back, which hit testing needs. `SCShareableContent.windows` has no stated order. Bounds and layer are readable without extra permission. Runner up: `SCShareableContent`, rejected for the order. Verify at build that bounds, order, and layer behave as expected on your macOS.
- **Window rect to display space**: window bounds arrive in global screen points with a top left origin on the primary display. Convert to the flipped, display local space of `SelectionView` by subtracting the display's origin (converted the same way). Pure function, unit tested.
- **Hit testing**: a pure function `WindowHitTester.window(at:in:)` that takes the display local point and the front to back list already filtered to layer 0, not Screencopy, at least 4 points, and clipped to the display. Lives in `ScreencopyCore`.
- **Modes**: `CaptureMode` enum (`portion`, `screen`, `window`) in `ScreencopyCore` with a raw string for saving and the 1, 2, 3 key mapping.
- **Capture rect by mode**: all three modes produce a display local selection rect and use the existing `RegionCropper`. Screen mode uses the full display bounds. Window mode uses the clipped window rect. Nothing changes after the crop.
- **Window level**: bar panel one level above the overlay panels, `collectionBehavior` the same (all Spaces, full screen auxiliary), `canBecomeKey` false, `becomesKeyOnlyIfNeeded`, `isMovableByWindowBackground` true. Fallback if clicks on the bar activate the app: handle `acceptsFirstMouse` and recheck the cancel observers.
- **Options menu**: an `NSMenu` popped from the button (not a SwiftUI `Menu`), so the panel never needs to become key. The cancel observer for "another app activated" must not fire for it; verify at build.
- **Saved values** (all in `UserDefaults`, no new package): `captureMode` (string, default `portion`), `toolbarEnabled` (bool, default true), `soundsEnabled` (bool, default true), `toolbarOrigin.<displayID>` (a point as fractions of the visible frame, so a resolution change keeps it sensible).
- **Which display gets the bar**: the screen that contains `NSEvent.mouseLocation` when the hotkey fires (the same hint point 0003 already takes), else the first screen.
- **Hover redraw**: `SelectionView` keeps a `hoverRect` (display local) and redraws only that layer on mouse moved. In screen mode the hover rect is the whole display.
- **Strings**: all fixed, listed in the ACs.

## Feature design

**Data model sketch**: no tables. Four `UserDefaults` keys listed above. In memory: the current `CaptureMode`, the window list for this capture (array of display independent frames, front to back, no names), and the hover rect.

**State transitions**: the coordinator states from 0003 are unchanged (`idle`, `snapshotting`, `selecting`, `finishing`). Inside `selecting` the mode moves between `portion`, `screen`, and `window` at any time except during a drag. A click in screen or window mode ends `selecting` the same way a finished drag does.

**API surface**:
| Function | Inputs | Outputs | Auth | Key errors |
|---|---|---|---|---|
| `CaptureCoordinator.setMode(_:)` | `CaptureMode` | saves the mode, updates all overlay views and the bar | none | ignored during a drag |
| `SelectionViewDelegate.selectionView(_:didClickAt:)` | display local point | in screen or window mode: finishes with the display or window rect; else nothing | none | nothing pickable: ignored |
| `WindowListing.frontToBackWindows()` | none | `[WindowInfo]` (frame, layer, owner process id) | screen recording permission already checked | thrown error becomes an empty list (AC-11) |
| `WindowHitTester.window(at:in:)` | point, window list, display size | the clipped rect or `nil` | none | none |
| `ToolbarPanel.show(on:mode:)` / `close()` | screen, mode | the bar on that screen | none | none |
| Options "Play sounds" | toggle | writes `soundsEnabled`; `NoticePresenter` reads it before it plays | none | none |
| Settings checkbox | toggle | writes `toolbarEnabled`; read at `start()` | none | none |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Show the bar | Which display | the screen containing the mouse at hotkey time (`NSEvent.mouseLocation`, as in 0003) |
| Show the bar | Position | saved `toolbarOrigin.<displayID>` as fractions of `screen.visibleFrame`, else bottom centre, 48 points above the visible bottom (AC-1) |
| Show the bar | Selected mode | saved `captureMode`, else `portion` |
| Screen mode click | Capture rect | `(0, 0, displaySize)` of the clicked display's `SelectionView` |
| Window mode hover and click | Window rect | global window bounds from `CGWindowListCopyWindowInfo`, converted to display local space and clipped to the display (conversion above) |
| Window mode | Which windows are pickable | layer 0, on screen, owner process is not Screencopy (`ProcessInfo.processInfo.processIdentifier`), at least 4 points each side |
| Window mode | Which window wins on overlap | first in the front to back list that contains the point |
| Cropped image | Pixels | `RegionCropper.crop` on the display snapshot, as in 0003 |
| Hint text and cursor | Text, cursor | fixed per mode (AC-12) |
| Sound | Whether to play | `soundsEnabled` default true |
| Toolbar on or off | Whether to show | `toolbarEnabled` default true |
| Key mapping | 1, 2, 3 to modes | `CaptureMode.key` |

**Key invariants**:
- Exactly one image is handed over per capture, from exactly one display (0003 AC-3).
- The bar and the overlays are created together and torn down together in the one `tearDown()`.
- The picture is always cut from the snapshot taken before any Screencopy window appeared, so no Screencopy window is in it.
- A mode change never changes the permission gate, snapshot, or text pipeline.

**Security model**: single user, local app. No new permission (the system window list gives bounds without extra access, and screen recording is already required). No network. Window names and owners are never read, stored, or logged. Images stay in memory only.

**Configuration required**: none. No new entitlement, package, or Info.plist key.

**Critical test scenarios**:
- Happy path: hotkey in another app, bar shows bottom centre of the display with the mouse, drag a box, text copied, verifies **AC-1**, **AC-2**, **AC-7**, **AC-16**.
- Screen mode: press 2, move between two displays (dimming lifts on the hovered one), click, pasted text matches the screen, verifies **AC-8**.
- Window mode: press 3, hover a window (outline), click, text matches the window area; overlap with a window in front; a window spanning two displays; click on the desktop does nothing, verifies **AC-9**, **AC-10**.
- Window list failure: fake lister throws, window mode opens with no highlight, other modes fine, verifies **AC-11**.
- Bar behaviour: drag it, relaunch, it is where you left it; unplug a display and the default spot is used; click on the bar never draws a box or captures, verifies **AC-3**, **AC-4**, **AC-5**.
- Keys and cancel: 1, 2, 3, Escape, close button; keys ignored mid drag; every 0003 cancel source closes the bar too; no bar in the image, verifies **AC-6**, **AC-15**.
- Options and Settings: toggle sounds and hear it, open the Options menu and the capture stays open, uncheck the Settings box and the hotkey gives the plain overlay, verifies **AC-13**, **AC-14**.
- Unit tests (no screen): `CaptureMode` keys and saving, `WindowHitTester` (front window wins, clipping, tiny windows, outside points, empty list), coordinate conversion with a second display left of and above the primary, verifies **AC-9**, **AC-10**, **AC-3**.

## Build plan

Approach is Skateboard: the bar with today's portion mode first, then the two new modes, then the extras.

1. **Pure pieces and saved values.** `CaptureMode`, `WindowInfo`, `WindowHitTester`, coordinate conversion, a small settings store over `UserDefaults`, with Swift Testing cases. Satisfies **AC-3**, **AC-9**, **AC-10**.
2. **Bar with portion mode.** `ToolbarPanel` and `CaptureToolbarView` with the three buttons (only portion does anything), close button, shown by the coordinator on the hinted display, drag and remembered position, bar never starts a capture and never appears in the image. Satisfies **AC-1**, **AC-2**, **AC-4**, **AC-5**, **AC-7**.
3. **Entire screen mode.** `setMode`, hover rect, click to finish with the full display rect. Satisfies **AC-8**.
4. **Selected window mode.** `WindowListing` in `ScreencopyCapture` with a fake, hover outline, click to finish with the window rect, failure path. Satisfies **AC-9**, **AC-10**, **AC-11**.
5. **Keys, hints, cursor, accessibility.** 1, 2, 3, Escape, close, per mode hint and cursor, labels and tooltips. Satisfies **AC-6**, **AC-12**, **AC-2**.
6. **Options and Settings.** Options menu with "Play sounds", `NoticePresenter` reads it, Settings checkbox, toolbar off path. Satisfies **AC-13**, **AC-14**.
7. **Robustness and verify pass.** Every cancel source closes the bar, repeat hotkey, no leftovers, no logging of names, run the test scenarios above. Satisfies **AC-15**, **AC-16**, and a check of **AC-1** to **AC-14**.

## Consequences

**Positive**:
- Reading a whole window or screen is one click instead of a careful drag.
- The mute and a way back to the plain flow are one click away.
- All three modes share one crop and one text pipeline, so little code is duplicated.

**Negative / tradeoffs**:
- One more window to keep correct in the cancel logic and window level setup.
- Window mode shows what is on screen. A covered part of a window is not recovered.
- Windows above layer 0 (some floating panels) cannot be picked; use portion mode for them.
- The bar is not a keyboard focus target. Number keys are the keyboard route.

**Neutral**:
- `ScreenCapturing` stays as it is. Window listing is a second small protocol.
- The Settings window from spec 0005 gains a row, so its fixed height changes.

## Follow-up

- [ ] Spec 0005 AC-6: add the "Show the toolbar when I capture" row to the Settings window description and adjust its fixed size.
- [ ] Spec 0004: replace "sound always on until settings offers a mute" with the Options toggle and the `soundsEnabled` key.
- [ ] Spec 0003: note that the overlay now also supports click captures and a bar; its drag rules stay as written.
- [ ] Feature 6 (language choice) may later add a language item to the Options menu. Not part of this spec.
- [ ] At build, verify: window list order and bounds on your macOS, that clicks on the bar do not activate the app or trip the cancel observers, and that the Options menu does not cancel the capture.
- [ ] Keyboard and VoiceOver access to the bar itself is limited because the panel cannot become key. Revisit if you want to tab through the buttons.

## Rationale

Reasoning and options: see the sections above. A SwiftUI view in a non activating panel is the least code that meets the 0003 rule that the app you were in stays active. Cropping the window area from the existing snapshot keeps one capture path, so every mode ends in the same crop, recognize, and copy steps. The system window list is chosen over ScreenCaptureKit's list only because hit testing needs a front to back order.
