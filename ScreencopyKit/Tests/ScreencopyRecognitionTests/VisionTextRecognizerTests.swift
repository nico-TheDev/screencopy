import CoreGraphics
import CoreText
import Foundation
import Testing

@testable import ScreencopyRecognition

@Suite struct VisionTextRecognizerTests {
    private func bitmap(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
        return context.makeImage()!
    }

    private func draw(_ lines: [String], in context: CGContext, height: Int) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 40, nil)
        for (index, line) in lines.enumerated() {
            // Text defaults to black, which is what the white fixture needs.
            let attributed = CFAttributedStringCreate(
                nil, line as CFString, [kCTFontAttributeName: font] as CFDictionary)!
            context.textPosition = CGPoint(x: 30, y: CGFloat(height - 70 - index * 70))
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
    }

    @Test func blankImageGivesNoText() async throws {
        let image = bitmap(width: 64, height: 64) { _ in }
        let result = try await VisionTextRecognizer().recognize(image, languages: nil)
        #expect(result.isEmpty)
    }

    @Test func threePrintedLinesComeBackInOrder() async throws {
        let lines = ["Hello world", "Second line here", "Third and last"]
        let image = bitmap(width: 600, height: 260) { draw(lines, in: $0, height: 260) }
        let result = try await VisionTextRecognizer().recognize(image, languages: nil)
        #expect(result.text == lines.joined(separator: "\n"))
    }
}
