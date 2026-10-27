import Testing

@testable import ScreencopyCore

@Suite struct CaptureOutcomeTests {
    @Test func singularAndPlural() {
        #expect(CaptureOutcome.copied(characterCount: 1, shortened: false).message == "Copied 1 character")
        #expect(CaptureOutcome.copied(characterCount: 42, shortened: false).message == "Copied 42 characters")
    }

    @Test func shortenedEntryIsSaidSo() {
        #expect(
            CaptureOutcome.copied(characterCount: 10_000, shortened: true).message
                == "Copied 10000 characters (shortened)")
    }

    @Test func copyFailureHasItsOwnWording() {
        #expect(CaptureOutcome.copyFailed.message == "Couldn't copy")
    }

    @Test func failureWordingDiffersFromNoText() {
        #expect(CaptureOutcome.noText.message == "No text found")
        #expect(CaptureOutcome.failed.message == "Couldn't read the selection")
    }
}
