import Testing

@testable import ScreencopyCore

struct MenuLabelsTests {
    @Test func titleShowsTheHotkey() {
        #expect(MenuLabels.captureTitle(shortcut: "⌥⇧2") == "Capture Text (⌥⇧2)")
    }

    @Test func titleIsPlainWithoutAHotkey() {
        #expect(MenuLabels.captureTitle(shortcut: nil) == "Capture Text")
        #expect(MenuLabels.captureTitle(shortcut: "") == "Capture Text")
    }
}
