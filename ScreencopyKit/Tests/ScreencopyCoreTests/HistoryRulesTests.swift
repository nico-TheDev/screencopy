import Foundation
import Testing

@testable import ScreencopyCore

@Suite struct HistoryRulesTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func list(_ texts: [String]) -> [HistoryEntry] {
        texts.reduce(into: []) { entries, text in
            entries = HistoryRules.recording(text: text, at: t0, id: UUID(), into: entries)
        }
    }

    @Test func newestComesFirst() {
        #expect(list(["a", "b", "c"]).map(\.text) == ["c", "b", "a"])
    }

    @Test func keepsTwentyAndDropsTheOldest() {
        let entries = list((1...25).map(String.init))
        #expect(entries.count == 20)
        #expect(entries.first?.text == "25")
        #expect(entries.last?.text == "6")
    }

    @Test func sameTextMovesToTheTopWithoutAduplicate() {
        let later = Date(timeIntervalSince1970: 2_000)
        let entries = HistoryRules.recording(text: "a", at: later, id: UUID(), into: list(["a", "b", "c"]))
        #expect(entries.map(\.text) == ["a", "c", "b"])
        #expect(entries.first?.capturedAt == later)
    }

    @Test func dedupeIsExact() {
        #expect(list(["a", "a ", "A"]).count == 3)
    }

    @Test func longTextIsCutAndFlagged() {
        let entries = HistoryRules.recording(
            text: String(repeating: "x", count: 12_000), at: t0, id: UUID(), into: [])
        #expect(entries.first?.text.count == 10_000)
        #expect(entries.first?.wasShortened == true)
    }

    @Test func textAtTheLimitIsKept() {
        let entries = HistoryRules.recording(
            text: String(repeating: "x", count: 10_000), at: t0, id: UUID(), into: [])
        #expect(entries.first?.wasShortened == false)
    }

    @Test func cutCountsCharactersNotScalars() {
        let text = String(repeating: "e\u{0301}", count: 10_001)
        let entry = HistoryRules.recording(text: text, at: t0, id: UUID(), into: []).first
        #expect(entry?.text.count == 10_000)
        #expect(entry?.wasShortened == true)
    }

    @Test func promotingMovesToTopAndKeepsTheFlag() {
        let long = HistoryRules.recording(
            text: String(repeating: "x", count: 10_050), at: t0, id: UUID(), into: [])
        let entries = HistoryRules.recording(text: "b", at: t0, id: UUID(), into: long)
        let now = Date(timeIntervalSince1970: 5_000)
        let promoted = HistoryRules.promoting(long[0], at: now, into: entries)
        #expect(promoted.count == 2)
        #expect(promoted.first?.wasShortened == true)
        #expect(promoted.first?.capturedAt == now)
        #expect(promoted.first?.id == long[0].id)
    }

    @Test func promotingAClearedEntryAddsItBack() {
        let entry = HistoryEntry(id: UUID(), text: "gone", capturedAt: t0, wasShortened: false)
        let entries = HistoryRules.promoting(entry, at: t0, into: [])
        #expect(entries == [entry])
    }
}
