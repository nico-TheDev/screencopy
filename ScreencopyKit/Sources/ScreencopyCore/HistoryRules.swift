import Foundation

/// How the history list changes. Pure, so it is tested without files or a screen.
/// The list is always newest first, has no two entries with the same text, and holds at most `maxEntries`.
public enum HistoryRules {
    public static let maxEntries = 20
    public static let maxTextLength = 10_000

    /// Adds a fresh capture. Text longer than `maxTextLength` characters is cut and flagged.
    public static func recording(
        text: String, at date: Date, id: UUID, into entries: [HistoryEntry]
    ) -> [HistoryEntry] {
        let wasShortened = text.count > maxTextLength
        let stored = wasShortened ? String(text.prefix(maxTextLength)) : text
        let entry = HistoryEntry(id: id, text: stored, capturedAt: date, wasShortened: wasShortened)
        return placingFirst(entry, in: entries)
    }

    /// Moves an existing entry to the top with a new time, or adds it back if it is no longer in the list.
    /// The text and the shortened flag stay as they were stored.
    public static func promoting(_ entry: HistoryEntry, at date: Date, into entries: [HistoryEntry]) -> [HistoryEntry] {
        let moved = HistoryEntry(id: entry.id, text: entry.text, capturedAt: date, wasShortened: entry.wasShortened)
        return placingFirst(moved, in: entries)
    }

    private static func placingFirst(_ entry: HistoryEntry, in entries: [HistoryEntry]) -> [HistoryEntry] {
        var result = entries.filter { $0.text != entry.text }
        result.insert(entry, at: 0)
        return Array(result.prefix(maxEntries))
    }
}
