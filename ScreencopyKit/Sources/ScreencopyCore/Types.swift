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

/// A still picture of one whole display. `pointSize` is the size ScreenCaptureKit reports for it,
/// so callers can check it against what AppKit says before trusting the picture.
public struct DisplaySnapshot: Sendable {
    public let displayID: CGDirectDisplayID
    public let image: CGImage
    public let pointSize: CGSize

    public init(displayID: CGDirectDisplayID, image: CGImage, pointSize: CGSize) {
        self.displayID = displayID
        self.image = image
        self.pointSize = pointSize
    }
}

/// Text read from a capture. `text` is already trimmed, so empty means nothing was found.
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
