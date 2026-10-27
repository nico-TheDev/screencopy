import CoreGraphics

/// One protocol per OS boundary, so logic can be tested with fakes.

public protocol ScreenCapturing: Sendable {
    /// One still picture per display, at native pixels, without Screencopy's own windows or the cursor.
    /// Throws if any one display cannot be captured, so callers never see a partial set.
    func snapshot(displays: [CGDirectDisplayID]) async throws -> [DisplaySnapshot]
}

public protocol TextRecognizer: Sendable {
    /// `languages == nil` means detect the language.
    func recognize(_ image: CGImage, languages: [String]?) async throws -> ExtractedText
}

@MainActor
public protocol ClipboardWriting {
    /// `false` when the pasteboard refused the text.
    func write(_ text: String) -> Bool
}

@MainActor
public protocol OutcomeNotifying {
    /// Replaces any notice on screen. `region` says where the capture happened. With no region (a history
    /// pick) the notice goes top center on the display under the mouse.
    func show(_ outcome: CaptureOutcome, region: CaptureRegion?)
    /// The "Reading..." notice, shown when recognition is slow.
    func showReading(region: CaptureRegion)
    /// Removes the notice at once.
    func dismiss()
}

public protocol WindowListing: Sendable {
    /// On screen windows, front most first. Throws when the system list cannot be read.
    func frontToBackWindows() throws -> [WindowInfo]
}
