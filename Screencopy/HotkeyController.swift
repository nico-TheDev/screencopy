import AppKit
@preconcurrency import KeyboardShortcuts
import os

extension KeyboardShortcuts.Name {
    /// The one place the capture hotkey is declared. Default is Option+Shift+2
    /// (Command+Shift+3/4/5 belong to macOS screenshots).
    static let capture = Self("capture", default: .init(.two, modifiers: [.option, .shift]))
}

@MainActor
final class HotkeyController {
    static let shared = HotkeyController()
    private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "hotkey")

    func start() {
        KeyboardShortcuts.onKeyDown(for: .capture) { [logger] in
            // Region capture (feature 3) replaces this.
            logger.info("capture hotkey pressed")
        }
    }
}
