import AppKit
import Observation
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The one place the capture hotkey is declared. Default is Option+Shift+2
    /// (Command+Shift+3/4/5 belong to macOS screenshots).
    static let capture = Self("capture", default: .init(.two, modifiers: [.option, .shift]))
}

/// Owns the capture hotkey and publishes its current value so the menu and Settings stay in step.
@MainActor
@Observable
final class HotkeyController {
    static let shared = HotkeyController()

    /// The hotkey as glyphs (for example "⌥⇧2"), or nil when none is set.
    private(set) var shortcutText: String?
    /// True while the stored shortcut is the default one.
    private(set) var isDefault = true

    /// The library posts this with the shortcut name whenever a shortcut is recorded, reset, or cleared.
    /// The name is internal to the library, so it is spelled out here.
    private static let changeNotification = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: Self.changeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name
            MainActor.assumeIsolated {
                if name == nil || name == .capture { self?.refresh() }
            }
        }
    }

    func start(onCapture: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .capture) {
            MainActor.assumeIsolated { onCapture() }
        }
    }

    func resetToDefault() {
        KeyboardShortcuts.reset(.capture)
    }

    private func refresh() {
        let current = KeyboardShortcuts.getShortcut(for: .capture)
        shortcutText = current?.description
        isDefault = current == KeyboardShortcuts.Name.capture.defaultShortcut
    }
}
