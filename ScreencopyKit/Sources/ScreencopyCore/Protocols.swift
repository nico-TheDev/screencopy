import CoreGraphics

/// One protocol per OS boundary, so logic can be tested with fakes.

public protocol ScreenCapturing: Sendable {
    func capture(_ region: CaptureRegion) async throws -> CGImage
}

public protocol TextRecognizer: Sendable {
    /// `languages == nil` means detect the language.
    func recognize(_ image: CGImage, languages: [String]?) async throws -> ExtractedText
}

public protocol ClipboardWriting: Sendable {
    func write(_ text: String)
}
