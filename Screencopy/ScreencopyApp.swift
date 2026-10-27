import ScreencopyCore
import SwiftUI

@main
struct ScreencopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button(MenuLabels.captureTitle(shortcut: HotkeyController.shared.shortcutText)) {
                appDelegate.triggerCapture()
            }
            RecentMenu(history: appDelegate.history)
            Divider()
            Button("Settings…") { appDelegate.showSettings() }
                .keyboardShortcut(",")
            Button("Quit Screencopy") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "text.viewfinder")
                .accessibilityLabel("Screencopy")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The Recent submenu: newest first, one line each. Labels are built here from the saved text and shown
/// as is, so captured text is never read as formatting.
private struct RecentMenu: View {
    let history: HistoryModel

    var body: some View {
        Menu("Recent") {
            if history.entries.isEmpty {
                Button("No captures yet") {}
                    .disabled(true)
            } else {
                ForEach(history.entries) { entry in
                    Button {
                        history.pick(entry)
                    } label: {
                        Text(verbatim: MenuLabels.recentTitle(for: entry.text))
                    }
                }
            }
            Divider()
            Button("Clear History") { history.clear() }
                .disabled(history.entries.isEmpty)
        }
    }
}
