import CoreGraphics

/// A rectangle the user dragged, in points, on one display.
public struct CaptureRegion: Sendable, Equatable {
    public let displayID: CGDirectDisplayID
    public let rect: CGRect

    public init(displayID: CGDirectDisplayID, rect: CGRect) {
        self.displayID = displayID
        self.rect = rect
    }
}

/// Text read from a capture. `text` is empty when nothing was found.
public struct ExtractedText: Sendable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum ScreencopyError: Error, Sendable, Equatable {
    case permissionDenied
    case captureFailed
    case recognitionFailed
}
