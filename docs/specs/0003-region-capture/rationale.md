# 0003. Region capture: frozen snapshot, drag a box, hand off the pixels (rationale)

## Context

Feature 3 in `docs/scope/scope.md`. Spec [0001](../0001-native-mac-stack/index.md) fixed the stack (macOS 14, Swift 6, AppKit overlay, ScreenCaptureKit, `KeyboardShortcuts`) and the scaffold already has: the hotkey (`HotkeyController`, default Option+Shift+2, currently only logs), the permission check (`ScreenRecordingPermission`), a status window, and the protocols `ScreenCapturing` and `ClipboardWriting` in `ScreencopyKit`. Text recognition and the clipboard arrive in feature 4.

Forces:
- The app is not the frontmost app when the hotkey fires, and must work over full screen apps and every Space.
- AppKit coordinates start bottom left, ScreenCaptureKit and `CGImage` start top left. Retina screens have more pixels than points. These two mismatches are the usual source of off by some pixels captures.
- Dimming drawn by the overlay must not end up in the result.
- Only one person uses this, on this Mac. Privacy rule from 0001: images stay in memory, never on disk, never logged.

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

## References

**Project sources**:
- Spec [0001](../0001-native-mac-stack/index.md): stack, privacy rules, and the open items for this feature
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
