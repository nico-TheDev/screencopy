import Foundation

/// Text for the menu bar menu. Kept free of UI types so it can be tested.
public enum MenuLabels {
    public static let recentMaxLength = 40
    public static let recentFallback = "(no visible text)"

    /// "Capture Text" with the current hotkey after it, or plain when no hotkey is set.
    public static func captureTitle(shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return "Capture Text" }
        return "Capture Text (\(shortcut))"
    }

    /// One line for a history entry: the first line with something visible, control and bidirectional
    /// override characters removed, runs of whitespace collapsed, cut to `recentMaxLength` characters.
    /// Built at display time and never stored.
    public static func recentTitle(for text: String) -> String {
        for line in text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            let cleaned = clean(line)
            guard !cleaned.isEmpty else { continue }
            guard cleaned.count > recentMaxLength else { return cleaned }
            return String(cleaned.prefix(recentMaxLength)) + "…"
        }
        return recentFallback
    }

    private static func clean(_ line: Substring) -> String {
        // Drop invisible controls first, so a tab still separates words but a bidi mark does not.
        var visible = String.UnicodeScalarView()
        for scalar in line.unicodeScalars where scalar.properties.isWhitespace || !isHidden(scalar) {
            visible.append(scalar)
        }
        return String(visible).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isHidden(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.generalCategory == .control { return true }
        switch scalar.value {
        case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069: return true
        default: return false
        }
    }
}
