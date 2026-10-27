import AppKit
import ScreencopyCore

/// Plain text on the general pasteboard. No concealed or transient markers: the user pastes it on purpose.
@MainActor
struct ClipboardWriter: ClipboardWriting {
    func write(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
