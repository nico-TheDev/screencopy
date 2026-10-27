import Foundation

/// One saved capture. Text only: an image never reaches history.
public struct HistoryEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let capturedAt: Date
    /// True when the captured text was cut to `HistoryRules.maxTextLength` before it was stored.
    public let wasShortened: Bool

    public init(id: UUID, text: String, capturedAt: Date, wasShortened: Bool) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.wasShortened = wasShortened
    }
}
