import CoreGraphics
import Foundation
import os

/// Turns one captured image into clipboard text and tells the user how it went.
/// Only the recognizer runs off the main actor. The clipboard is written only for non empty text
/// from a run that is still the current one.
@MainActor
public final class TextCapturePipeline {
    /// A selection thinner than this (in points) is treated as "No text found" without running Vision.
    public static let minimumSide: CGFloat = 8

    private let recognizer: any TextRecognizer
    private let clipboard: any ClipboardWriting
    private let notifier: any OutcomeNotifying
    private let history: any HistoryRecording
    private let readingDelay: Duration
    private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "capture")

    private var generation = 0
    private var task: Task<Void, Never>?

    public init(
        recognizer: any TextRecognizer,
        clipboard: any ClipboardWriting,
        notifier: any OutcomeNotifying,
        history: any HistoryRecording,
        readingDelay: Duration = .milliseconds(300)
    ) {
        self.recognizer = recognizer
        self.clipboard = clipboard
        self.notifier = notifier
        self.history = history
        self.readingDelay = readingDelay
    }

    public func start(image: CGImage, region: CaptureRegion) {
        cancelCurrent()
        let box = region.rect.standardized
        guard box.width >= Self.minimumSide, box.height >= Self.minimumSide else {
            finish(.noText, region: region)
            return
        }
        let run = generation
        task = Task {
            let reading = Task {
                try? await Task.sleep(for: readingDelay)
                guard !Task.isCancelled, run == generation else { return }
                notifier.showReading(region: region)
            }
            let result: Result<ExtractedText, Error>
            do {
                result = .success(try await recognizer.recognize(image, languages: nil))
            } catch {
                result = .failure(error)
            }
            reading.cancel()
            // Vision cannot be stopped, so a stale result is dropped here instead.
            guard run == generation, !Task.isCancelled else { return }
            finish(outcome(for: result), region: region)
        }
    }

    /// Reports a capture that failed before recognition (for example the crop came back empty).
    public func reportCaptureFailure(region: CaptureRegion) {
        cancelCurrent()
        finish(.failed, region: region)
    }

    /// Drops any run in progress and clears the notice. Called when the capture hotkey is pressed.
    public func cancelCurrent() {
        generation += 1
        task?.cancel()
        task = nil
        notifier.dismiss()
    }

    /// Waits for the current run to end. For tests.
    func finished() async {
        await task?.value
    }

    private func outcome(for result: Result<ExtractedText, Error>) -> CaptureOutcome {
        guard case .success(let extracted) = result else { return .failed }
        let text = extracted.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .noText }
        guard clipboard.write(text) else { return .failed }
        history.record(text: text)
        return .copied(characterCount: text.count, shortened: false)
    }

    private func finish(_ outcome: CaptureOutcome, region: CaptureRegion) {
        // Outcome only: the image and the text are never logged.
        logger.info("capture outcome: \(String(describing: outcome.kind))")
        notifier.show(outcome, region: region)
    }
}

extension CaptureOutcome {
    fileprivate var kind: String {
        switch self {
        case .copied: "copied"
        case .noText: "noText"
        case .failed: "failed"
        case .copyFailed: "copyFailed"
        }
    }
}
