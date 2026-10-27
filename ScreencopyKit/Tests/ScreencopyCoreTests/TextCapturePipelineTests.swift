import CoreGraphics
import Testing
import os

@testable import ScreencopyCore

private struct FakeRecognizer: TextRecognizer {
    let behavior: @Sendable (Int) async throws -> ExtractedText
    let calls = OSAllocatedUnfairLock(initialState: 0)

    func recognize(_ image: CGImage, languages: [String]?) async throws -> ExtractedText {
        let call = calls.withLock { value -> Int in
            value += 1
            return value
        }
        return try await behavior(call)
    }
}

@MainActor
private final class FakeClipboard: ClipboardWriting {
    var written: [String] = []
    var succeeds = true

    func write(_ text: String) -> Bool {
        guard succeeds else { return false }
        written.append(text)
        return true
    }
}

@MainActor
private final class FakeHistory: HistoryRecording {
    var recorded: [String] = []

    func record(text: String) { recorded.append(text) }
}

@MainActor
private final class FakeNotifier: OutcomeNotifying {
    enum Event: Equatable {
        case outcome(CaptureOutcome)
        case reading
        case dismissed
    }
    var events: [Event] = []

    func show(_ outcome: CaptureOutcome, region: CaptureRegion?) { events.append(.outcome(outcome)) }
    func showReading(region: CaptureRegion) { events.append(.reading) }
    func dismiss() { events.append(.dismissed) }

    var outcomes: [CaptureOutcome] {
        events.compactMap { if case .outcome(let outcome) = $0 { outcome } else { nil } }
    }
}

@MainActor
@Suite struct TextCapturePipelineTests {
    private let image: CGImage = {
        let context = CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }()
    private let region = CaptureRegion(displayID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 40))
    private let clipboard = FakeClipboard()
    private let notifier = FakeNotifier()
    private let history = FakeHistory()

    private func pipeline(
        readingDelay: Duration = .milliseconds(300),
        _ behavior: @escaping @Sendable (Int) async throws -> ExtractedText
    ) -> (TextCapturePipeline, FakeRecognizer) {
        let recognizer = FakeRecognizer(behavior: behavior)
        let pipeline = TextCapturePipeline(
            recognizer: recognizer, clipboard: clipboard, notifier: notifier, history: history,
            readingDelay: readingDelay)
        return (pipeline, recognizer)
    }

    @Test func copiesTextAndReportsTheCount() async {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: "hello\nworld") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(clipboard.written == ["hello\nworld"])
        #expect(notifier.outcomes == [.copied(characterCount: 11, shortened: false)])
    }

    @Test func recordsTheFinalTextInHistory() async {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: "hello\nworld") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(history.recorded == ["hello\nworld"])
    }

    @Test func nothingIsRecordedWithoutCopiedText() async {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: " ") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        let (failing, _) = self.pipeline { _ in throw ScreencopyError.recognitionFailed }
        failing.start(image: image, region: region)
        await failing.finished()
        clipboard.succeeds = false
        let (refused, _) = self.pipeline { _ in ExtractedText(text: "hi") }
        refused.start(image: image, region: region)
        await refused.finished()
        failing.reportCaptureFailure(region: region)
        #expect(history.recorded.isEmpty)
    }

    @Test func countsGraphemesNotScalars() async {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: "e\u{0301}") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(notifier.outcomes == [.copied(characterCount: 1, shortened: false)])
    }

    @Test func whitespaceOnlyLeavesClipboardAlone() async {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: " \n ") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(clipboard.written.isEmpty)
        #expect(notifier.outcomes == [.noText])
    }

    @Test func recognitionErrorLeavesClipboardAloneAndFails() async {
        let (pipeline, _) = pipeline { _ in throw ScreencopyError.recognitionFailed }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(clipboard.written.isEmpty)
        #expect(notifier.outcomes == [.failed])
    }

    @Test func clipboardRefusingTheWriteFails() async {
        clipboard.succeeds = false
        let (pipeline, _) = pipeline { _ in ExtractedText(text: "hi") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(notifier.outcomes == [.failed])
    }

    @Test func tinyRegionNeverCallsTheRecognizer() async {
        let (pipeline, recognizer) = pipeline { _ in ExtractedText(text: "x") }
        pipeline.start(image: image, region: CaptureRegion(displayID: 1, rect: CGRect(x: 0, y: 0, width: 4, height: 4)))
        await pipeline.finished()
        #expect(recognizer.calls.withLock { $0 } == 0)
        #expect(notifier.outcomes == [.noText])
        #expect(clipboard.written.isEmpty)
    }

    @Test func secondCaptureCancelsTheFirst() async {
        let (pipeline, _) = pipeline { call in
            if call == 1 { try await Task.sleep(for: .milliseconds(150)) }
            return ExtractedText(text: call == 1 ? "first" : "second")
        }
        pipeline.start(image: image, region: region)
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        try? await Task.sleep(for: .milliseconds(250))
        #expect(clipboard.written == ["second"])
        #expect(notifier.outcomes == [.copied(characterCount: 6, shortened: false)])
    }

    @Test func cancelCurrentIsSilent() async {
        let (pipeline, _) = pipeline { _ in
            try await Task.sleep(for: .milliseconds(100))
            return ExtractedText(text: "late")
        }
        pipeline.start(image: image, region: region)
        pipeline.cancelCurrent()
        try? await Task.sleep(for: .milliseconds(250))
        #expect(clipboard.written.isEmpty)
        #expect(notifier.outcomes.isEmpty)
        #expect(notifier.events.contains(.dismissed))
    }

    @Test func slowRecognitionShowsReadingFirst() async {
        let (pipeline, _) = pipeline(readingDelay: .milliseconds(20)) { _ in
            try await Task.sleep(for: .milliseconds(150))
            return ExtractedText(text: "done")
        }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        #expect(notifier.events.suffix(2) == [.reading, .outcome(.copied(characterCount: 4, shortened: false))])
    }

    @Test func fastRecognitionSkipsReading() async {
        let (pipeline, _) = pipeline(readingDelay: .milliseconds(200)) { _ in ExtractedText(text: "quick") }
        pipeline.start(image: image, region: region)
        await pipeline.finished()
        try? await Task.sleep(for: .milliseconds(250))
        #expect(!notifier.events.contains(.reading))
    }

    @Test func captureFailureBeforeRecognitionReportsFailed() {
        let (pipeline, _) = pipeline { _ in ExtractedText(text: "x") }
        pipeline.reportCaptureFailure(region: region)
        #expect(notifier.outcomes == [.failed])
    }
}
