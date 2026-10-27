import CoreGraphics
import Testing

@testable import ScreencopyCore

@Suite struct ReadingOrderTests {
    private func fragment(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.05) -> TextFragment {
        TextFragment(text: text, box: CGRect(x: x, y: y, width: w, height: h))
    }

    @Test func sortsRowsTopToBottom() {
        // Vision's origin is the bottom left, so a larger y is higher on screen.
        let text = ReadingOrder.text(from: [
            fragment("last", x: 0, y: 0.1),
            fragment("first", x: 0, y: 0.8),
            fragment("middle", x: 0, y: 0.4),
        ])
        #expect(text == "first\nmiddle\nlast")
    }

    @Test func joinsBoxesOnOneVisualLineWithASpace() {
        let text = ReadingOrder.text(from: [
            fragment("world", x: 0.5, y: 0.502),
            fragment("hello", x: 0.1, y: 0.5),
        ])
        #expect(text == "hello world")
    }

    @Test func separateLinesStayApart() {
        let text = ReadingOrder.text(from: [
            fragment("a", x: 0, y: 0.5),
            fragment("b", x: 0, y: 0.44),
        ])
        #expect(text == "a\nb")
    }

    @Test func trimsOnlyTheWholeString() {
        let text = ReadingOrder.text(from: [
            fragment("  indented", x: 0, y: 0.8),
            fragment("tail  ", x: 0, y: 0.4),
        ])
        #expect(text == "indented\ntail")
    }

    @Test func emptyInputGivesEmptyText() {
        #expect(ReadingOrder.text(from: []).isEmpty)
    }
}
