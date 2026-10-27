/// Where history is kept between launches. The pipeline never sees this: it only knows `HistoryRecording`.
public protocol HistoryStoring: Sendable {
    /// The saved list, newest first. A missing file gives an empty list. A file that cannot be read is set
    /// aside and gives an empty list, so this never throws.
    func load() async -> [HistoryEntry]
    /// Replaces the saved list in one step, so a crash never leaves a half written file.
    func save(_ entries: [HistoryEntry]) async throws
    /// Deletes the set aside copy of a bad file, if there is one.
    func removeBackup() async throws
}

/// Called by the pipeline when a capture ends with text on the clipboard.
@MainActor
public protocol HistoryRecording {
    /// Adds the final text. A failure to save is logged and never reaches the caller.
    func record(text: String)
}
