/// How one capture ended. A cancelled capture has no outcome: it is silent.
public enum CaptureOutcome: Sendable, Equatable {
    /// `shortened` is true only when a history entry that was cut at 10,000 characters is picked.
    case copied(characterCount: Int, shortened: Bool)
    case noText
    case failed
    /// A history pick could not write the clipboard.
    case copyFailed

    /// The words shown in the notice. Never includes the copied text.
    public var message: String {
        switch self {
        case .copied(let count, let shortened):
            "Copied \(count) \(count == 1 ? "character" : "characters")" + (shortened ? " (shortened)" : "")
        case .noText: "No text found"
        case .failed: "Couldn't read the selection"
        case .copyFailed: "Couldn't copy"
        }
    }

    public static let readingMessage = "Reading..."
}
