import CoreGraphics

/// One piece of text Vision found, with its box in Vision's space:
/// normalized 0 to 1, origin at the bottom left.
public struct TextFragment: Sendable, Equatable {
    public let text: String
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}

/// Turns Vision's unordered boxes into the text as you see it on screen.
/// Vision does not promise reading order, and one visual line can come back as several boxes.
public enum ReadingOrder {
    /// Two boxes share a row when their vertical overlap is at least this share of the shorter one.
    public static let rowOverlap: CGFloat = 0.5

    /// Rows top to bottom joined with newlines, boxes inside a row left to right joined with a space.
    /// Only the whole string is trimmed.
    public static func text(from fragments: [TextFragment]) -> String {
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let anchor = rows.last?.first, sharesRow(anchor.box, fragment.box) {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return
            rows
            .map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sharesRow(_ a: CGRect, _ b: CGRect) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        let shorter = min(a.height, b.height)
        return shorter > 0 && overlap >= shorter * rowOverlap
    }
}
