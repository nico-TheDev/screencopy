import Testing

@testable import ScreencopyCore

@Suite struct MenuLabelsRecentTests {
    @Test func plainLineIsKept() {
        #expect(MenuLabels.recentTitle(for: "hello world") == "hello world")
    }

    @Test func usesTheFirstLineWithVisibleText() {
        #expect(MenuLabels.recentTitle(for: "\n\t  \n\u{00A0}\u{3000}\n  second \n third") == "second")
    }

    @Test func collapsesRunsOfWhitespace() {
        #expect(MenuLabels.recentTitle(for: "a \t\t b   c") == "a b c")
    }

    @Test func cutsAtFortyCharactersWithAnEllipsis() {
        let label = MenuLabels.recentTitle(for: String(repeating: "x", count: 100))
        #expect(label == String(repeating: "x", count: 40) + "…")
    }

    @Test func exactlyFortyIsNotCut() {
        let text = String(repeating: "x", count: 40)
        #expect(MenuLabels.recentTitle(for: text) == text)
    }

    @Test func removesControlAndBidiOverrideCharacters() {
        #expect(MenuLabels.recentTitle(for: "ab\u{202E}cd\u{0007}ef\u{2066}g") == "abcdefg")
    }

    @Test func aLineOfOnlyHiddenCharactersIsSkipped() {
        #expect(MenuLabels.recentTitle(for: "\u{202E}\u{200F}\nreal") == "real")
    }

    @Test func nothingVisibleGivesAFallback() {
        #expect(MenuLabels.recentTitle(for: "\u{202E}") == MenuLabels.recentFallback)
    }
}
