# 0007. Keep the last 20 captures as text, and re copy them from the menu

**Date**: 2026-10-28
**Status**: In Progress

## Summary

Every successful capture is also saved as text in a small file on your Mac. A Recent submenu in the menu bar lists the last 20, one line each. Picking one puts its full text back on the clipboard, and Clear History empties the list. Only text is stored, never images, and the file can only be read by your user account.

## Requirements

**User stories**:
- As the owner, I want to copy a recent capture again so that I do not have to recapture it.
- As the owner, I want to clear the list so that private text does not stay around.

**Acceptance criteria**:
- **AC-1**: Each capture that ends with text on the clipboard (spec 0004 outcome `copied`) is added to history as text with its capture time. No image is ever stored. No capture that ended in no text or failure is added.
- **AC-2**: History keeps the 20 most recent entries; adding a 21st drops the oldest.
- **AC-3**: An entry with text identical to an existing entry does not create a second one; the existing entry moves to the top with a new time.
- **AC-4**: The menu has a "Recent" submenu (between Capture Text and Settings…) listing entries newest first. Each line is the first line of the text that has any non whitespace character (Unicode whitespace counts), with control and bidirectional override characters removed and runs of whitespace collapsed to single spaces, cut to 40 characters (`String.count`) with "…" added if cut. No timestamps. Labels use `Text(verbatim:)`. When empty, the submenu shows a disabled "No captures yet". A divider comes before Clear History.
- **AC-5**: Picking an entry writes the menu item's own copy of the text to the clipboard (so it works even if the entry was just cleared), shows the notice "Copied N characters" (with " (shortened)" if the entry was shortened) with the capture sound (spec 0004), and moves that entry to the top with the capture time set to now (adding it back if it no longer exists). The notice appears top center of the display under the mouse because there is no capture region. If the clipboard write fails, the notice says "Couldn't copy" with the failure sound and the list is unchanged. Picking does not cancel a recognition in progress.
- **AC-6**: The submenu ends with "Clear History", disabled when empty. It empties the list at once, with no confirmation, deletes the backup file (AC-10), and the stored file no longer contains any text.
- **AC-7**: History survives quitting and relaunching. Order, text, and the shortened flag come back exactly as saved. Dates are saved with fractional seconds.
- **AC-8**: One stored entry holds at most 10,000 characters. The clipboard always gets the full captured text on a capture. A shortened entry stores `wasShortened = true`; copying it from history gives the shortened text.
- **AC-9**: The history folder is mode 0700, set at every launch, and the file is mode 0600 after every write (including the second and later writes). The folder is excluded from Time Machine backups.
- **AC-10**: If the history file is missing at launch, history starts empty. If it cannot be read or parsed (or has an unknown version), history starts empty, the bad file is renamed to `history.json.bak` (mode 0600, replacing any older backup), and an error with no content is logged.
- **AC-11**: Writing is atomic (a temp file created with mode 0600 in the same folder, then renamed over `history.json`), so a crash never leaves a half written file. If a write fails, the error is logged without content, memory keeps the correct list, the next change retries the save, and the capture itself still succeeds.
- **AC-12**: Adds, picks, and clears made quickly in any order end with a file equal to the final list. A capture that arrives before the load finishes is held and merged after the load, and never overwrites saved history.
- **AC-13**: Nothing in history touches the network, and no text, text length, or entry id appears in logs.

## Decision

**Chosen option**: Option 1: One JSON file in Application Support

A `HistoryStore` keeps the list in memory, saves it to one JSON file after each change, and the menu bar reads from it.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`)

**RECOMMEND calls made here**:
- **Where**: `~/Library/Application Support/com.norbertoignacio.screencopy/history.json`, from `FileManager.urls(for: .applicationSupportDirectory)`. Folder created with mode 0700, file set to 0600 after each write. Runner up: Caches, rejected because the system may delete it.
- **Shape**: `{ "version": 1, "entries": [ { "id": UUID, "text": String, "capturedAt": ISO 8601 date with fractional seconds, "wasShortened": Bool } ] }`, newest first. A `version` field lets a later release change the format. Unknown versions are treated as a bad file (AC-10).
- **Code layout and ownership**: the `@MainActor @Observable` `HistoryModel` in the app target owns the list. The rules (dedupe, limit of 20, 10,000 character cut, move to top) are a pure function `HistoryRules.applying(...)` in `ScreencopyCore`, tested without files. `HistoryEntry` (`Codable`, `Sendable`) and the `HistoryStoring` protocol are in `ScreencopyCore`; `FileHistoryStore` (a Swift `actor` that only loads and saves) is in a new `ScreencopyHistory` target, which needs a library product and a test target in `Package.swift`. `HistoryRecording` is a `@MainActor` protocol with a synchronous `record(text:)`. Logging uses the bundle id subsystem with category `history`. Runner up: everything in the app target, rejected because it loses the tests.
- **Loading and the startup race**: the model starts a load at launch off the main thread. Until it finishes, saves are blocked and the submenu shows "No captures yet". Any `record` made before the load finishes is held and applied to the loaded list afterwards. Runner up: block launch, rejected because it could delay the menu icon.
- **Order of operations on add**: apply `HistoryRules` (dedupe, insert at top, truncate to 20, shorten text and set `wasShortened`), update the in memory list, then queue a save of that list. Saves go through one `AsyncStream` consumer so they reach the store in the order they were made, and a failed save is retried on the next change (AC-11, AC-12).
- **Storage safety**: at every launch set the folder to 0700 and `isExcludedFromBackup`. Write a temp file in the same folder created with mode 0600, then rename it over `history.json`. Clear History deletes `history.json.bak` and rewrites `history.json` with an empty list.
- **Dedupe key**: exact string equality of the stored (shortened) text. Runner up: ignore case or whitespace, rejected as surprising.
- **Menu label**: built at display time from the stored text, never stored. Runner up: store the label, rejected as derived data that could go stale.
- **Clear**: writes an empty `entries` list rather than deleting the file, so the file always exists in a valid state. Runner up: delete the file, rejected as an extra case to handle.
- **Notice without a region**: `OutcomeNotifying.show` from spec 0004 takes an optional `CaptureRegion`; with none, it uses the top center fallback on the display under the mouse. `CaptureOutcome.copied` gains `shortened`, and a `copyFailed` case is added. Spec 0004 has been amended for this.
- **Hook point**: the spec 0004 pipeline reports the `copied` outcome with the final text to the injected `HistoryRecording`, so the pipeline stays testable and does not know about files.
- **Separate debug bundle id** (spec 0005 follow up): a debug build would use its own history folder. That is acceptable.

## Feature design

**Data model sketch**:
| Entity | Fields | Rules |
|---|---|---|
| `HistoryEntry` | `id` UUID (required, unique), `text` String (required, non empty, at most 10,000 characters), `capturedAt` Date (required), `wasShortened` Bool (required) | Unique by `text` within the list. Newest first. At most 20 entries. |
| History file | `version` Int (required), `entries` [HistoryEntry] | One file, replaced atomically, mode 0600. |

No relationships. No other tables.

**State transitions**: none per entry. The list changes by three actions only: add (or move to top), pick (which moves to top), clear.

**API surface** (in process, no network):
| Function | Inputs | Outputs | Auth | Key errors |
|---|---|---|---|---|
| `HistoryRecording.record(text:)` (called by the pipeline on `copied`) | `String` | none | none | save failure is logged, never thrown to the pipeline |
| `HistoryModel.entries` | none | newest first list for the menu | none | none |
| `HistoryModel.pick(entry)` | `HistoryEntry` | writes clipboard, shows notice, moves to top | none | clipboard write false shows the failure notice (spec 0004) |
| `HistoryModel.clear()` | none | empty list, saved | none | save failure logged |
| `HistoryStoring.load()` / `save(entries)` | `[HistoryEntry]` | `[HistoryEntry]` / none | none | unreadable file handled as AC-10 |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Add | The stored text | The text spec 0004 wrote to the clipboard, cut to 10,000 characters |
| Add | `capturedAt` | `Date()` when `record` is called |
| Add | `id` | New `UUID()` |
| Menu line | First non empty line, collapsed, 40 characters | Derived from `text` at display time |
| Pick | Notice count N | `String.count` of the stored text, plus " (shortened)" if the original was cut |
| Add | `wasShortened` | True when the captured text was longer than 10,000 characters, set at add time and stored |
| Pick | Time and position | `capturedAt` set to now, moved to the top |
| Pick | Notice position | Top center of the `NSScreen` containing the mouse location, no region |
| Load | File path | Application Support folder plus bundle id, from `FileManager` |
| Clear | The empty file contents | `{ "version": 1, "entries": [] }` |

**Key invariants**:
- At most 20 entries, no two with the same text, newest first.
- The saved file is never newer than memory, and equals it once pending saves finish.
- No image ever reaches `HistoryEntry`.
- Text is never logged. Only error types and entry counts are.
- A failure to save never blocks or fails a capture.

**Security model**: Single user, local app. The history file is the first place the app stores captured text, so it is readable only by your account (0600, folder 0700), holds text only, is not encrypted (a chosen tradeoff), and is emptied by Clear History. Not sandboxed (spec 0001), so Application Support is a normal home folder path. No compliance scope.

**Configuration required**: none. No new entitlements, no new package dependency.

**Critical test scenarios**:
- Happy path: add three captures, restart the store from the same temporary folder, the list matches in order, verifies **AC-1**, **AC-7**.
- Limit and dedupe: add 25 distinct texts and keep 20, newest first; add a text that exists and it moves to the top without a duplicate, verifies **AC-2**, **AC-3**.
- Shortening: a 12,000 character text stores 10,000, the pick notice reads "(shortened)", verifies **AC-8**.
- Bad file: write garbage, load, history is empty, a backup file exists, no content in logs, verifies **AC-10**, **AC-13**.
- Save failure: a store pointing at a read only folder, the capture still succeeds and the list in memory is right, verifies **AC-11**.
- Permissions: after save, the file mode is 0600 and the folder 0700, verifies **AC-9**.
- Order under load: many quick adds and a clear, final file matches the final list, verifies **AC-12**.
- Menu label: a text with leading blank lines and tabs, a 100 character line, verifies **AC-4**.
- Manual in `/check verify`: Recent submenu in the real menu, pick puts the text in another app, Clear History empties it, relaunch restores it, nothing uses the network (search the source), verifies **AC-4**, **AC-5**, **AC-6**, **AC-13**.

## Build plan

Approach is Skateboard: a working list you can pick from first, then the limits and edge cases.

1. Add `HistoryEntry`, `HistoryStoring`, and `FileHistoryStore` (new `ScreencopyHistory` target) with load, atomic save, permissions, and the bad file path. Test with temporary folders, satisfies **AC-7**, **AC-9**, **AC-10**, **AC-11**, **AC-13**.
2. Add the add rules (dedupe, 20 limit, 10,000 characters, ordering through the actor), satisfies **AC-1**, **AC-2**, **AC-3**, **AC-8**, **AC-12**.
3. Add the `HistoryRecording` hook to the spec 0004 pipeline and the `HistoryModel` in the app target, satisfies **AC-1**.
4. Add the Recent submenu, the label rule, pick (clipboard, notice with no region), and Clear History to the menu from spec 0005, satisfies **AC-4**, **AC-5**, **AC-6**.
5. Make `OutcomeNotifying` accept a missing region and use the top center fallback, satisfies **AC-5**.

## Consequences

**Positive**:
- Recover a capture you lost without taking it again.
- Small, dependency free, easy to inspect or delete by hand.
- The pipeline and the store are tested without a screen.

**Negative / tradeoffs**:
- Captured text now lives on disk, unencrypted, and can include secrets. Clear History and mode 0600 are the only protection.
- Rewriting the whole file after each change is fine at this size but would not scale to a large history.
- A shortened entry cannot be restored to its full length.
- Clear History rewrites the file, but the old bytes may remain on disk (and in APFS snapshots) until overwritten. Encryption is out of scope.
- Picking an entry puts possibly secret text back on the clipboard, where clipboard managers can read it.
- Exact match dedupe keeps near duplicates (same text, different whitespace).

**Neutral**:
- No setting to turn history off, and no search. Either can be a later feature.
- The menu from spec 0005 grows beyond three items.

## Follow-up

- [ ] Specs 0004 and 0005 were amended for this feature (optional region, `shortened`, history exception, menu items). The build of 0004 should include the `HistoryRecording` hook.
- [ ] Keep the menu built in one place so the Recent submenu fits.
- [ ] Spec 0001 says history is text only and stores "decided in the history spec"; update its Follow-up once this is accepted.
- [ ] Consider a Settings switch to turn history off, if you capture sensitive text often.

