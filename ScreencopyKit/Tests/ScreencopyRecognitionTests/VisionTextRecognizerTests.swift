import CoreGraphics
import Testing
@testable import ScreencopyRecognition

@Suite struct VisionTextRecognizerTests {
    @Test func blankImageGivesNoText() async throws {
        let context = CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let result = try await VisionTextRecognizer().recognize(context.makeImage()!, languages: nil)
        #expect(result.isEmpty)
    }
}
