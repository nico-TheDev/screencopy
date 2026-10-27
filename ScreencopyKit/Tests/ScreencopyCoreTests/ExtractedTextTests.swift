import Testing
@testable import ScreencopyCore

@Suite struct ExtractedTextTests {
    @Test func whitespaceOnlyCountsAsEmpty() {
        #expect(ExtractedText(text: " \n\t ").isEmpty)
    }

    @Test func realTextIsNotEmpty() {
        #expect(!ExtractedText(text: "hello").isEmpty)
    }
}
