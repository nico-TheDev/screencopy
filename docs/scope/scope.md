# Scope: Screencopy

A Mac app that works like the Windows Snipping Tool, but instead of an image it puts the text it finds in your screenshot on the clipboard. Built for one person (you), and everything stays on your Mac.

**Build approach:** Skateboard (ship the smallest complete product you would actually use, then grow it release by release).
**Workflow:** Alpha (after develop, run check verify). The project default level of rigor. `/architect` is the recommended first stop for a feature with a real decision, but skippable when you already know the build. Any feature can carry its own tag (e.g. `· GA`) to do more or less.

_These are recommendations to keep your build orderly, not requirements. Skip anything that does not fit: if you already know how to build a feature, use `/develop` and skip `/architect`. You decide when a feature is `done`._

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 1 | Stack & architecture | Foundation | done |
| 2 | Coding standards & tooling | Foundation | done |
| 3 | Region capture | Release 1 | done |
| 4 | Recognize and copy text | Release 1 | done |
| 5 | Menu bar app & settings | Release 2 | in-progress |
| 6 | Language choice | Release 3 | in-progress |
| 7 | Capture history | Release 4 | in-progress |
| 8 | Floating capture toolbar | Release 2 | in-progress |

## Foundations

### 1. Stack & architecture
Decide how the app is built (native or cross platform shell, and how text is recognized on device) and scaffold a runnable project.
**Done when:** the decision is recorded in a spec, the scaffold launches on your Mac, and it can ask for and receive the screen recording permission.
spec [0001](../specs/0001-native-mac-stack/index.md) · code in `Screencopy/`, `ScreencopyKit/`
- [x] Decide the stack (spec): `/architect stack & architecture`
- [x] Scaffold from the decision: `/develop stack & architecture`
- [ ] Verify it: `/check verify stack & architecture` · skipped

### 2. Coding standards & tooling
Capture conventions and install lint, format, and pre-commit checks from the real scaffolded project.
**Done when:** root `AGENTS.md` reflects the real stack, and lint and format run clean.
spec [0002](../specs/0002-swift-standards-and-tooling.md)
- [x] Decide the standard (spec): `/architect standard and tooling`
- [ ] Capture conventions and tooling choices: `/audit` · skipped
- [x] Install the tooling: `/develop tooling`

## Release 1: the smallest usable whole

Press a hotkey, drag a box over some text, and the text is on your clipboard. Nothing else. No menu bar icon yet, no history, one default language, hotkey fixed.

### 3. Region capture
A global hotkey dims the screen and lets you drag a rectangle, like the Snipping Tool, then hands the selected pixels onward. Handles the Mac screen recording permission and cancelling with Escape.
**Done when:** the hotkey works from any app, you can drag a box (including on a second display) and cancel it, and a missing permission shows a clear message that points to the right setting.
spec [0003](../specs/0003-region-capture/index.md) · code in `Screencopy/` (`CaptureCoordinator`, `SelectionView`, `OverlayPanel`), `ScreencopyKit/` (`RegionCropper`, `ScreenCaptureKitCapturer`)
- [x] Design it (spec): `/architect region capture`
- [x] Build it: `/develop region capture`
  - [x] Crop math and screen snapshot in the package (AC-4, AC-5, AC-12)
  - [x] Hotkey to cropped image on one display, with permission gate and debug preview (AC-1 to AC-4, AC-11)
  - [x] Cancel rules and all displays (AC-2, AC-6 to AC-9)
  - [x] Overlay polish, failure messages, and cleanup (AC-10 to AC-14)
- [ ] Verify it: `/check verify region capture` · skipped

### 4. Recognize and copy text
Reads the text in the selected region on this Mac only, puts it on the clipboard, and tells you it worked (or that nothing was found).
**Done when:** a capture of printed text pastes into another app with the right characters and line breaks, no network is used, and an empty or unreadable selection gives a clear "no text found" signal without overwriting your clipboard.
spec [0004](../specs/0004-recognize-and-copy-text.md) · code in `Screencopy/` (`NoticePresenter`, `ClipboardWriter`), `ScreencopyKit/` (`TextCapturePipeline`, `ReadingOrder`, `CaptureOutcome`, `VisionTextRecognizer`)
- [x] Design it (spec): `/architect recognize and copy text`
- [x] Build it: `/develop recognize and copy text`
  - [x] Recognizer ordering and trim, with fixture tests (AC-1, AC-10)
  - [x] Pipeline, outcomes, cancel, clipboard writer (AC-3 to AC-6, AC-9, AC-11, AC-13, AC-15)
  - [x] Notice panel, sounds, VoiceOver, wired to capture (AC-2, AC-7, AC-8, AC-12, AC-14)
- [ ] Verify it: `/check verify recognize and copy text` · skipped

## Release 2: lives in the menu bar

### 5. Menu bar app & settings
A menu bar icon so the app is always running and easy to quit, plus a small settings window to change the hotkey.
**Done when:** the app shows a menu bar icon with capture and quit, you can change the hotkey and it persists across restarts, and a clashing hotkey is reported (best effort).
spec [0005](../specs/0005-menu-bar-app-and-settings.md) · code in `Screencopy/` (`ScreencopyApp`, `AppDelegate`, `HotkeyController`, `SettingsView`), `ScreencopyKit/` (`MenuLabels`)
- [x] Design it (spec): `/architect menu bar app & settings`
- [ ] Build it: `/develop menu bar app & settings`
  - [ ] Default hotkey check, menu bar icon, menu bar only mode, Quit (AC-1, AC-2, AC-5, AC-13)
  - [x] triggerCapture, owned Settings window, recorder and Reset (AC-3, AC-4, AC-6, AC-7, AC-9)
  - [ ] Clash messages, single instance, permission at launch (AC-8, AC-10, AC-11, AC-12)
- [ ] Verify it: `/check verify menu bar app & settings`

### 8. Floating capture toolbar
A small floating bar that appears over the dimmed screen when you press the hotkey, like the macOS screenshot tool (Shift Command 5). It holds buttons for how to capture (drag a region, whole screen, a window), an Options menu for settings that matter at capture time, and a close button.
**Done when:** pressing the hotkey shows the bar on the screen you are using, each button starts its capture mode and the text lands on the clipboard, Escape or the close button dismisses it, and the bar can be turned off in settings to keep today's drag only flow.
spec [0008](../specs/0008-floating-capture-toolbar.md) · code in `Screencopy/` (`ToolbarPanel`, `SelectionView`, `CaptureCoordinator`, `SettingsView`, `NoticePresenter`), `ScreencopyKit/` (`CaptureMode`, `CaptureSettings`, `ToolbarPlacement`, `WindowHitTester`, `SystemWindowLister`)
- [x] Design it (spec): `/architect floating capture toolbar`
- [x] Build it: `/develop floating capture toolbar`
  - [x] Pure pieces, saved values, and the bar with portion mode (AC-1 to AC-5, AC-7, AC-9, AC-10)
  - [x] Entire screen and selected window modes (AC-8 to AC-11)
  - [x] Keys, hints, accessibility, Options menu, Settings switch (AC-2, AC-6, AC-12 to AC-14)
  - [x] Cancel rules, cleanup, and privacy (AC-15, AC-16)
- [ ] Verify it: `/check verify floating capture toolbar`

## Release 3: other languages

### 6. Language choice
Pick the recognition language (or let it detect) so non English text copies correctly.
**Done when:** you can choose a language in settings, a capture in that language comes out right, and the choice persists.
spec [0008](../specs/0008-language-choice.md) · code in `Screencopy/` (`LanguageSettings`, `SettingsView`, `AppDelegate`), `ScreencopyKit/` (`RecognitionLanguages`, `TextCapturePipeline`, `VisionTextRecognizer`)
- [x] Design it (spec): `/architect language choice`
- [ ] Build it: `/develop language choice`
  - [ ] Language rules and pipeline wiring (AC-2, AC-3, AC-4, AC-6, AC-9)
  - [ ] Vision supported list and `LanguageSettings` storage (AC-1, AC-5, AC-7, AC-9)
  - [ ] Settings picker, note, and help line (AC-1, AC-6, AC-8)
  - [ ] Real French capture check (AC-10)
- [ ] Verify it: `/check verify language choice`

## Release 4: history

### 7. Capture history
Keep recent captures and their text so you can copy one again without recapturing.
**Done when:** recent captures are listed from the menu bar, picking one puts its text on the clipboard, you can clear the list, and history survives a restart.
spec [0007](../specs/0007-capture-history/index.md) · code in `Screencopy/` (`HistoryModel`, `ScreencopyApp`), `ScreencopyKit/` (`HistoryRules`, `HistoryEntry`, `ScreencopyHistory/FileHistoryStore`, `MenuLabels`)
- [x] Design it (spec): `/architect capture history`
- [x] Build it: `/develop capture history`
  - [x] Store, rules, and safe file handling with tests (AC-1 to AC-3, AC-7 to AC-13)
  - [x] Pipeline hook and history model (AC-1)
  - [x] Recent submenu, pick, Clear History, notice without a region (AC-4 to AC-6)
- [ ] Verify it: `/check verify capture history`

## Deferred
Out of scope for the current build pass, kept so the plan stays honest.
- **Start at login**: the app launches itself when you sign in · needs a decision
- **Keep the image too**: save or copy the screenshot, with simple markup, like the full Snipping Tool
- **Windows version**: a port, only if you ever want it · needs a decision
- **Cloud recognition**: better accuracy on messy handwriting, but sends screen content out; you chose on device only

## Legend

**The decision box.** Every feature carries exactly one, the sub-task whose label ends with `(spec)`. Its wording varies (`Design it (spec)` normally, `Decide the stack (spec)` on Stack & architecture), so skills locate it by that `(spec)` suffix, never by an exact label. Every other box is an execution box and `/architect` never ticks one.

**Feature lifecycle**: the scope updates as a feature moves; each row is what it shows and who sets it:

| State | Set by | The feature shows |
|---|---|---|
| `planned` · needs a decision | `/scope` | one box: `Design it (spec): /architect <feature>` |
| `in-progress` (designed) | **`/architect` at spec capture** | `Design it` ticked; spec linked; `Build it: /develop <feature>` + **2 to 5 milestones**; the tier's closing boxes (`Verify it` Alpha+, `Test it` Beta+, `Review it` + `Document it` GA); any surfaced follow-up enrolled |
| `in-progress` (building) | `/develop` | milestone sub-boxes tick one by one; code pointer filled |
| `in-progress` (verified) | `/check verify` | `Build it` + milestones ticked; `Verify it` ticked |
| `done` | **you, when you decide it is** (any skill sets it when you say so); `/sync` reconciles | boxes you ran ticked, skipped ones marked skipped; the tier's last stage (`Prototype` → after `/develop`; `Alpha` → after `/check verify`; `Beta`/`GA` → after `/test`) is the suggested point to call it done; `/sync` captures conventions |

- **Next step** = the first unticked box (always a command or a tracked milestone).
- **needs a decision** = run `/architect` first; otherwise straight to `/develop` (or `/audit` for standards & tooling). The tag drops once the spec is captured.
- **Atomic build tasks live in the spec's `## Build plan`, not here**: the scope carries only the milestone rollup.
- **Status** `planned` → `in-progress` → `done`, plus `existing` (pre-workflow) and `dropped` (de-scoped, kept for history).
- **Approach tag** beside a heading (e.g. `· Facade`) overrides the project default for that feature; no tag = inherits it.
- **Workflow tier tag** beside a heading (e.g. `· GA`, `· Prototype`) sets that one feature's rigor above or below the project default; no tag inherits the default.
- **Workflow** (header line) is the project default, what runs after `/develop`: **Prototype** = nothing; **Alpha** = `/check verify`; **Beta** = `/check verify` then `/test`; **GA** = adds a fresh model `/check review` then `/document`. A feature built on an unratified decision (an `Assumed` spec) stays flagged, but that never blocks `done`.
- **Pointer line** (`spec <n> · code in <path>`): the spec link added by `/architect`, the code path by `/develop`.
