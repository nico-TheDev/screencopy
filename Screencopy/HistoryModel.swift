import Foundation
import Observation
import ScreencopyCore
import os

/// The recent captures the menu shows. Owns the list in memory and keeps the saved file equal to it.
/// Loading happens off the main thread. Until it finishes, nothing is saved, the menu reads "No captures yet",
/// and captures that arrive are held and merged into the loaded list. A failed save never touches a capture.
@MainActor
@Observable
final class HistoryModel: HistoryRecording {
    private struct SaveRequest: Sendable {
        let entries: [HistoryEntry]
        let removesBackup: Bool
    }

    private struct HeldCapture {
        let text: String
        let date: Date
        let id: UUID
    }

    private(set) var entries: [HistoryEntry] = []

    @ObservationIgnored private let store: any HistoryStoring
    @ObservationIgnored private let clipboard: any ClipboardWriting
    @ObservationIgnored private let notifier: any OutcomeNotifying
    @ObservationIgnored private let saveRequests: AsyncStream<SaveRequest>.Continuation
    @ObservationIgnored private let saver: Task<Void, Never>
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var held: [HeldCapture] = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "history")

    init(store: any HistoryStoring, clipboard: any ClipboardWriting, notifier: any OutcomeNotifying) {
        self.store = store
        self.clipboard = clipboard
        self.notifier = notifier
        let (stream, continuation) = AsyncStream.makeStream(of: SaveRequest.self)
        saveRequests = continuation
        let logger = logger
        // One consumer, so saves reach the store in the order the changes were made.
        saver = Task {
            for await request in stream {
                if request.removesBackup {
                    do { try await store.removeBackup() } catch {
                        logger.error("history backup could not be deleted: \(String(describing: type(of: error)))")
                    }
                }
                do { try await store.save(request.entries) } catch {
                    // Memory keeps the right list; the next change saves the whole list again.
                    logger.error("history could not be saved: \(String(describing: type(of: error)))")
                }
            }
        }
    }

    deinit {
        saveRequests.finish()
    }

    /// Starts the load. Call once, after this copy of the app knows it is the running one.
    func start() {
        Task {
            let loaded = await store.load()
            finishLoading(loaded)
        }
    }

    // MARK: HistoryRecording

    func record(text: String) {
        guard isLoaded else {
            held.append(HeldCapture(text: text, date: Date(), id: UUID()))
            return
        }
        entries = HistoryRules.recording(text: text, at: Date(), id: UUID(), into: entries)
        save()
    }

    // MARK: Menu actions

    /// Puts the entry's own text back on the clipboard. `entry` is the menu item's copy, so this still
    /// works if the list was cleared after the menu was drawn.
    func pick(_ entry: HistoryEntry) {
        guard clipboard.write(entry.text) else {
            notifier.show(.copyFailed, region: nil)
            return
        }
        notifier.show(.copied(characterCount: entry.text.count, shortened: entry.wasShortened), region: nil)
        guard isLoaded else { return }
        entries = HistoryRules.promoting(entry, at: Date(), into: entries)
        save()
    }

    func clear() {
        guard isLoaded else { return }
        entries = []
        save(removesBackup: true)
    }

    // MARK: Loading and saving

    private func finishLoading(_ loaded: [HistoryEntry]) {
        isLoaded = true
        entries = loaded
        let waiting = held
        held = []
        for capture in waiting {
            entries = HistoryRules.recording(text: capture.text, at: capture.date, id: capture.id, into: entries)
        }
        if !waiting.isEmpty { save() }
    }

    private func save(removesBackup: Bool = false) {
        saveRequests.yield(SaveRequest(entries: entries, removesBackup: removesBackup))
    }
}
