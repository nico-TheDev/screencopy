# 0005. Run Screencopy from the menu bar, with a small settings window

**Date**: 2026-10-28
**Status**: In Progress

## Summary

Screencopy becomes a menu bar app with no Dock icon. The menu has Capture Text (showing your hotkey), Settings, and Quit. The Settings window has one row where you record a new hotkey, plus a Reset button. The hotkey is saved between launches. The menu icon is built with SwiftUI's `MenuBarExtra` (a ready made menu bar item).

## Context

Release 1 runs as a normal app with a Dock icon (spec [0001](0001-native-mac-stack/index.md)) because without a Dock icon or menu bar icon the app could not be quit. This feature adds the menu bar icon, switches the app to menu bar only, and adds the one setting the scope asks for: the hotkey.

Already in the scaffold: `ScreencopyApp` with an empty `Settings` scene, `AppDelegate` that shows the permission status window and ignores last window close, `HotkeyController` using `KeyboardShortcuts` with `.capture` defaulting to Option+Shift+2. Spec [0003](0003-region-capture.md) adds `CaptureCoordinator.start()` as the single capture entry point and keeps the permission status window. Spec [0004](0004-recognize-and-copy-text.md) leaves sound always on until settings offers a mute, which this feature does not add.

Hotkey clash detection is best effort on macOS. The system does not tell an app which keys another app already owns.

## Requirements

**User stories**:
- As the owner, I want a menu bar icon so the app is always running, easy to find, and easy to quit.
- As the owner, I want to change the hotkey so it does not clash with other apps.

**Acceptance criteria**:
- **AC-1**: On launch the app shows a menu bar icon (SF Symbol `text.viewfinder`, template image, accessibility label "Screencopy") and never shows a Dock icon, not even briefly. It opens no window, except the permission status window when screen recording permission is missing.
- **AC-2**: The icon menu has "Capture Text", "Settings…" (key equivalent ⌘,), and "Quit Screencopy" (⌘Q), in that order. In Release 4 spec [0007](0007-capture-history/index.md) adds a "Recent" submenu between Capture Text and Settings….
- **AC-3**: Capture Text and the hotkey both call one function, `triggerCapture()`. It cancels a recognition still running (spec 0004), ignores the press if a capture is already in progress (spec 0003), then calls `CaptureCoordinator.start()`, including its permission message. The menu item shows the current hotkey and updates when the hotkey changes. With no hotkey set it shows plain "Capture Text".
- **AC-4**: "Settings…" opens the Settings window in front of other apps. Closing it never quits the app.
- **AC-5**: Quit ends the app immediately, including while snapshotting or recognizing. (While the overlay is open the menu bar is covered, so Quit is not reachable then. That is expected.)
- **AC-6**: The Settings window (title "Screencopy Settings", about 400 points wide, fixed size) has a "Capture hotkey:" recorder, a "Reset to default" button (disabled when already at Option Shift 2), and the help text below. The hotkey can also be cleared; with none set, capture works only from the menu.
- **AC-7**: A changed hotkey takes effect at once and still works after quitting and relaunching the app.
- **AC-8**: A clashing hotkey is reported best effort. The library's own alerts for system reserved shortcuts and menu item conflicts are accepted as they are. If the OS refuses to register the chosen keys (only if the library reports it), the previous hotkey stays active and a red line under the recorder says "That shortcut could not be registered. Your previous shortcut is still active." It clears on the next successful record, Reset, or clear. The help text says: "Shortcuts already used by other apps may not be detected."
- **AC-9**: Pressing keys inside the recorder never starts a capture.
- **AC-10**: Launching a second copy of the app quits that copy and opens Settings in the running one. A relaunch from Finder or Spotlight (reopen) also opens Settings.
- **AC-11**: The permission status window is shown at launch only when permission is missing. Otherwise it appears only when a capture fails, as spec 0003 defines.
- **AC-12**: If the saved hotkey cannot be registered at launch, the failure is logged (no content) and the status window comes forward with a plain line saying so.
- **AC-13**: The default hotkey registers and fires on the macOS version the owner runs. If it does not, the default is changed (in `HotkeyController` and spec 0001) before this feature is done.

## Options considered

### Option 1: `MenuBarExtra` (menu style) with a SwiftUI Settings scene

SwiftUI scene for the menu, standard Settings scene for the window, `KeyboardShortcuts.Recorder` for the hotkey.

**Pros**:
- Least code, standard look, works on macOS 14.
- Settings scene and recorder already fit the scaffold.

**Cons**:
- Little control over the status item, and opening Settings from an accessory app needs an explicit app activation.

### Option 2: AppKit `NSStatusItem` with an `NSMenu`

Hand built status item.

**Pros**:
- Full control of icon and click behavior, reliable window opening.

**Cons**:
- More code to hold for a three item menu.

### Option 3: `MenuBarExtra` window style

A popover with custom SwiftUI content.

**Pros**:
- Room for richer UI later.

**Cons**:
- Not a native menu, and heavy for three items.

## Decision

**Chosen option**: Option 1: `MenuBarExtra` (menu style) with a SwiftUI Settings scene

Add a `MenuBarExtra` to `ScreencopyApp` (it becomes the one scene SwiftUI needs, replacing the empty `Settings` scene), mark the app menu bar only in Info.plist, and show the hotkey recorder in a window the app owns.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`)

**RECOMMEND calls made here**:
- **Menu bar only mode**: set `LSUIElement` to `YES` in Info.plist, so no Dock icon ever appears (setting the policy at launch can flash one). This changes 0001's "switch at runtime" plan. The permission status window can still be brought forward with `NSApp.activate()`. Runner up: `NSApp.setActivationPolicy(.accessory)` at launch, rejected for the Dock flash.
- **Opening Settings**: no SwiftUI `Settings` scene. `AppDelegate` owns an `NSWindow` hosting the settings view, the same way it already owns the status window, so the menu item, the reopen handler, and the second launch notification all call one `showSettings()`. It calls `NSApp.activate()` then `makeKeyAndOrderFront`. If the window still opens behind other apps, switch to `.regular` policy while it is open and back on close. Runner up: the SwiftUI `openSettings` action, rejected because it can only be called from inside a view.
- **Single instance**: at launch check `NSRunningApplication.runningApplications(withBundleIdentifier:)`, ignoring the current process. If another exists, post a distributed notification named `<bundleID>.openSettings` (no payload) and terminate this copy. The running copy calls `showSettings()`. Most relaunches come through the reopen handler instead; this covers `open -n`, a second build, and Xcode runs. Runner up: ignore, rejected because two copies fight over the hotkey.
- **Clash message**: use the library's own alerts. Whether `KeyboardShortcuts` (pinned at 1.17.0) reports a registration failure is not verified; check at build. If it does not, drop the red line and keep the help text. Runner up: probing for clashes by registering a test hotkey, rejected as unreliable.
- **Capture Text item label**: keep the current shortcut in an `@Observable` value refreshed from the library's change notification, and build the label from the shortcut's string form. Do not rely on a SwiftUI shortcut modifier, which is probably not in 1.17.
- **Default hotkey risk**: macOS 15 and later are reported to refuse Option only or Option+Shift only combinations for global hotkeys. This is from memory and unverified. Test ⌥⇧2 first on your macOS. If it fails, pick a new default such as ⌃⇧2, update `HotkeyController` and spec 0001, and consider upgrading `KeyboardShortcuts` to 2.x (its recorder blocks such shortcuts).
- **Reopen**: `applicationShouldHandleReopen` opens Settings (it shows the status window today).
- **Quit**: `NSApp.terminate(nil)`. No confirmation, no waiting for a running capture, since nothing is saved.

## Feature design

**Data model sketch**: No tables. One stored value: the capture shortcut, saved by `KeyboardShortcuts` in `UserDefaults` under the name `capture` (declared once in `HotkeyController`). Default Option+Shift+2. Cleared means no value.

**State transitions**: none beyond the app lifecycle: launch (single instance check, accessory mode, hotkey registered) then running then quit.

**API surface**:
| Function | Inputs | Outputs | Auth | Key errors |
|---|---|---|---|---|
| `ScreencopyApp` `MenuBarExtra` | none | menu with three items | none | none |
| `triggerCapture()` (hotkey and menu) | none | cancels recognition, ignores repeats, calls `CaptureCoordinator.start()` | none | permission and snapshot messages (spec 0003) |
| `AppDelegate.showSettings()` | none | the Settings window in front | none | none |
| Settings window | recorder, Reset button | stored shortcut | none | alert for reserved keys, red line for failed registration |
| Second launch handler | none | opens Settings in the running app | none | none |

**Value sourcing**:
| Action | Value displayed or produced | Source |
|---|---|---|
| Menu item label | Current hotkey glyphs | `KeyboardShortcuts.getShortcut(for: .capture)`, held in an observable value refreshed on the library's change notification |
| Settings | Window title, size, labels, help text | Fixed in AC-6 and AC-8 |
| Permission window | Text about capture | Replace the stale "Capture arrives in the next release" line in `PermissionStatusView` |
| Recorder | Current shortcut | `UserDefaults` through `KeyboardShortcuts` |
| Reset | Default shortcut | The `default:` declared on `.capture` in `HotkeyController` |
| Inline message | Clash or failure text | Fixed strings in the app, one for rejected reserved keys, one for failed registration, one general note about other apps |
| Launch | "Permission missing" decision | `ScreenRecordingPermission.status()` |
| Second launch | Which instance to notify | `NSRunningApplication` for `Bundle.main.bundleIdentifier` |

**Key invariants**:
- Exactly one running instance owns the hotkey.
- The hotkey and the menu item call the same capture entry point.
- The app is never in accessory mode without the Quit item reachable.
- No capture can start while a hotkey is being recorded.

**Security model**: Single user, local app. The settings store only a shortcut. No network. No new permission: the global hotkey uses Carbon registration, which needs no Accessibility permission (spec 0001).

**Configuration required**: none. No new entitlements. No new Swift package.

**Critical test scenarios**:
- Happy path: launch, see the icon and no Dock icon, open Settings from the menu, record a new hotkey, quit and relaunch, the new hotkey still works, verifies **AC-1**, **AC-4**, **AC-6**, **AC-7**.
- Menu paths: Capture Text starts a capture, Quit exits during a capture, verifies **AC-2**, **AC-3**, **AC-5**.
- Failure case: record a reserved system shortcut and one used by a menu item, see the message; record a combination that the OS refuses (if one can be found), the old hotkey stays, verifies **AC-8**.
- Recorder: while recording, pressing the current hotkey does not start a capture (the library should pause shortcuts while recording; check, do not build), verifies **AC-9**.
- Default hotkey: press ⌥⇧2 on the real macOS, the log shows it fired, verifies **AC-13**. Unregistrable saved hotkey shows the status window, verifies **AC-12**.
- Screencopy's own Settings window is not in the overlay snapshot (spec 0003 excludes its windows). That is expected.
- Second launch: start a second copy, it exits and Settings opens in the first, verifies **AC-10**.
- Permission: reset with `tccutil reset ScreenCapture com.norbertoignacio.screencopy`, launch, the status window appears; grant, relaunch, it does not, verifies **AC-11**.
- Logic that can be tested without the UI (pure helpers such as the label from a shortcut) goes in `ScreencopyKit` tests. The rest is checked in `/check verify`.

## Build plan

Approach is Skateboard: the smallest usable menu bar app first, then the settings.

1. First test that ⌥⇧2 registers and fires on your macOS and change the default if not, satisfies **AC-13**.
2. Add the `MenuBarExtra` with the three items, the `text.viewfinder` icon and its label, set `LSUIElement`, drop the empty `Settings` scene, make Quit work, satisfies **AC-1**, **AC-2**, **AC-5**.
3. Add `triggerCapture()` and route both the hotkey and the menu item through it (until feature 3 lands, the current `HotkeyController` log stub), show the shortcut on the item with the observable label, satisfies **AC-3**.
4. Add `showSettings()` with the owned window, recorder, Reset, help text, and the reopen handler, satisfies **AC-4**, **AC-6**, **AC-7**, **AC-9**.
5. Add the clash and registration messages and the launch time registration failure path, verify what the library reports, satisfies **AC-8**, **AC-12**.
6. Add the single instance check and notification, the launch time permission check for the status window, and fix the stale permission text, satisfies **AC-10**, **AC-11**.

## Consequences

**Positive**:
- The app is quittable, always running, and out of the Dock.
- The hotkey is changeable and saved with almost no custom code.
- One entry point serves both menu and hotkey.

**Negative / tradeoffs**:
- Clash reporting is best effort. A key owned by another app can still silently fail.
- Opening Settings from an accessory app needs an activation workaround and may need a fallback on macOS 14.
- With no Dock icon, a crash or a stuck launch is easy to miss, because nothing shows.

**Neutral**:
- Sound mute, language choice, and start at login are not here. Language (feature 6) will add to this window. Start at login stays in the Deferred list.
- History (feature 7) will add a menu section, so the menu is not fixed at three items forever.

## Follow-up

- [ ] At build, verify: the library's pinned version (1.17.0) reports a failed registration, whether the Option based default works on your macOS, and whether the Settings window comes in front without the policy switch fallback.
- [ ] Update spec 0001: the runtime `setActivationPolicy(.accessory)` plan becomes `LSUIElement`, and the default hotkey if it changes.
- [ ] A separate debug bundle id could let an Xcode run coexist with an installed copy; decide at build.
- [ ] Spec 0004 left sounds always on "until settings offers a mute". Decide in a later spec whether a mute switch is wanted; it is not part of this one.
- [ ] Spec 0003 describes the status window coming forward from `AppDelegate`; after the accessory switch, confirm it still comes to the front and can be closed without quitting.
- [ ] Feature 7 (capture history) adds a menu section; keep the menu built in one place so it can grow.

## Rationale

The scope asked for an icon, a menu with capture and quit, and a hotkey setting, so the smallest thing that does exactly that is a plain menu style `MenuBarExtra` plus the recorder the project already depends on. A hand built status item would only pay off for icon states and custom clicks, which you chose not to have. The single instance rule exists because a menu bar app with no Dock icon gives no sign it is already running, and two copies would fight over one hotkey.
