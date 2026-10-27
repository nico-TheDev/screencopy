# 0007. Capture history (rationale)

## Context

Release 4 lets you copy an earlier capture again without capturing it again. Spec [0001](../0001-native-mac-stack/index.md) already fixed two rules: history stores recognized text only, never images, and no content is logged. It left the store open. Spec [0004](../0004-recognize-and-copy-text.md) defines the pipeline whose success outcome feeds this feature and the notice shown after copying. Spec [0005](../0005-menu-bar-app-and-settings.md) defines the menu bar menu that gains the submenu.

The data is small (20 short entries) and is the first time the app writes captured text to disk. Captured text can contain passwords or private messages, so the file protection and the clear action matter more than the storage technology.

## Options considered

### Option 1: One JSON file in Application Support

A versioned list of entries, rewritten atomically after every change.

**Pros**:
- No dependency, easy to inspect, back up, and delete. Fits 20 short rows.

**Cons**:
- Whole file rewritten on each change (a few hundred KB at most with the size cap).
- Text sits unencrypted on disk.

### Option 2: UserDefaults

Store the list under a key.

**Pros**:
- Least code.

**Cons**:
- Meant for small settings, mixes captured text into the preferences file, and is harder to clear cleanly.

### Option 3: SwiftData or SQLite

A real database.

**Pros**:
- Room for search and large history later.

**Cons**:
- Heavy for 20 rows, adds schema upkeep, and the scope has no such need.

## Rationale

The scope only asks for a recent list that survives a restart and can be cleared, so the smallest store that does that is a single JSON file; a database would be more machinery than 20 short rows need. The real risk is not storage but privacy, since this is the first time captured text touches disk. That is why the file is user only, text only, size capped, never logged, and has a one step Clear History, and why encryption was left out as extra failure modes for a one person Mac app.
