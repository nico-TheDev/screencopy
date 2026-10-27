# Scope: Screencopy

A Mac app that works like the Windows Snipping Tool, but instead of an image it puts the text it finds in your screenshot on the clipboard. Built for one person (you), and everything stays on your Mac.

**Build approach:** Skateboard (ship the smallest complete product you would actually use, then grow it release by release).
**Workflow:** Alpha (after develop, run check verify). The project default level of rigor. `/architect` is the recommended first stop for a feature with a real decision, but skippable when you already know the build. Any feature can carry its own tag (e.g. `· GA`) to do more or less.

_These are recommendations to keep your build orderly, not requirements. Skip anything that does not fit: if you already know how to build a feature, use `/develop` and skip `/architect`. You decide when a feature is `done`._

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 1 | Stack & architecture | Foundation | in-progress |
| 2 | Coding standards & tooling | Foundation | in-progress |
| 3 | Region capture | Release 1 | in-progress |
| 4 | Recognize and copy text | Release 1 | in-progress |
| 5 | Menu bar app & settings | Release 2 | planned |
| 6 | Language choice | Release 3 | planned |
| 7 | Capture history | Release 4 | planned |

## Foundations

### 1. Stack & architecture
Decide how the app is built (native or cross platform shell, and how text is recognized on device) and scaffold a runnable project.
**Done when:** the decision is recorded in a spec, the scaffold launches on your Mac, and it can ask for and receive the screen recording permission.
spec [0001](../specs/0001-native-mac-stack/index.md) · code in `Screencopy/`, `ScreencopyKit/`
- [x] Decide the stack (spec): `/architect stack & architecture`
- [x] Scaffold from the decision: `/develop stack & architecture`
- [ ] Verify it: `/check verify stack & architecture`

### 2. Coding standards & tooling
Capture conventions and install lint, format, and pre-commit checks from the real scaffolded project.
**Done when:** root `AGENTS.md` reflects the real stack, and lint and format run clean.
spec [0002](../specs/0002-swift-standards-and-tooling.md)
- [x] Decide the standard (spec): `/architect standard and tooling`
- [ ] Capture conventions and tooling choices: `/audit`
- [ ] Install the tooling: `/develop tooling`

## Release 1: the smallest usable whole

Press a hotkey, drag a box over some text, and the text is on your clipboard. Nothing else. No menu bar icon yet, no history, one default language, hotkey fixed.

### 3. Region capture
A global hotkey dims the screen and lets you drag a rectangle, like the Snipping Tool, then hands the selected pixels onward. Handles the Mac screen recording permission and cancelling with Escape.
**Done when:** the hotkey works from any app, you can drag a box (including on a second display) and cancel it, and a missing permission shows a clear message that points to the right setting.
spec [0003](../specs/0003-region-capture.md)
- [x] Design it (spec): `/architect region capture`
- [ ] Build it: `/develop region capture`
  - [ ] Crop math and screen snapshot in the package (AC-4, AC-5, AC-12)
  - [ ] Hotkey to cropped image on one display, with permission gate and debug preview (AC-1 to AC-4, AC-11)
  - [ ] Cancel rules and all displays (AC-2, AC-6 to AC-9)
  - [ ] Overlay polish, failure messages, and cleanup (AC-10 to AC-14)
- [ ] Verify it: `/check verify region capture`

### 4. Recognize and copy text
Reads the text in the selected region on this Mac only, puts it on the clipboard, and tells you it worked (or that nothing was found).
**Done when:** a capture of printed text pastes into another app with the right characters and line breaks, no network is used, and an empty or unreadable selection gives a clear "no text found" signal without overwriting your clipboard.
spec [0004](../specs/0004-recognize-and-copy-text.md)
- [x] Design it (spec): `/architect recognize and copy text`
- [ ] Build it: `/develop recognize and copy text`
  - [ ] Recognizer ordering and trim, with fixture tests (AC-1, AC-10)
  - [ ] Pipeline, outcomes, cancel, clipboard writer (AC-3 to AC-6, AC-9, AC-11, AC-13, AC-15)
  - [ ] Notice panel, sounds, VoiceOver, wired to capture (AC-2, AC-7, AC-8, AC-12, AC-14)
- [ ] Verify it: `/check verify recognize and copy text`

## Release 2: lives in the menu bar

### 5. Menu bar app & settings · needs a decision
A menu bar icon so the app is always running and easy to quit, plus a small settings window to change the hotkey.
**Done when:** the app shows a menu bar icon with capture and quit, you can change the hotkey and it persists across restarts, and a clashing hotkey is reported.
- [ ] Design it (spec): `/architect menu bar app & settings`

## Release 3: other languages

### 6. Language choice
Pick the recognition language (or let it detect) so non English text copies correctly.
**Done when:** you can choose a language in settings, a capture in that language comes out right, and the choice persists.
- [ ] Build it: `/develop language choice`

## Release 4: history

### 7. Capture history · needs a decision
Keep recent captures and their text so you can copy one again without recapturing.
**Done when:** recent captures are listed from the menu bar, picking one puts its text on the clipboard, you can clear the list, and history survives a restart.
- [ ] Design it (spec): `/architect capture history`

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
