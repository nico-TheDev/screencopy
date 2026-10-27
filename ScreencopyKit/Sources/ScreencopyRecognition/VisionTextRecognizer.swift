import CoreGraphics
import ScreencopyCore
import Vision

public struct VisionTextRecognizer: TextRecognizer {
    public init() {}

    public func recognize(_ image: CGImage, languages: [String]?) async throws -> ExtractedText {
        // Vision is synchronous; run it off the caller's actor and hand back a plain value.
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if let languages {
                request.recognitionLanguages = languages
                request.automaticallyDetectsLanguage = false
            } else {
                request.automaticallyDetectsLanguage = true
            }
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                throw ScreencopyError.recognitionFailed
            }
            let fragments = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map { TextFragment(text: $0.string, box: observation.boundingBox) }
            }
            return ExtractedText(text: ReadingOrder.text(from: fragments))
        }.value
    }
}
