import KeyboardShortcuts
import ScreencopyCore
import SwiftUI

/// The Settings window content: the capture hotkey and whether the capture toolbar shows.
struct SettingsView: View {
    let hotkey: HotkeyController
    @AppStorage(CaptureSettings.Key.toolbarEnabled) private var toolbarEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Show the toolbar when I capture", isOn: $toolbarEnabled)
            HStack {
                KeyboardShortcuts.Recorder("Capture hotkey:", name: .capture)
                Button("Reset to default") { hotkey.resetToDefault() }
                    .disabled(hotkey.isDefault)
            }
            Text("Shortcuts already used by other apps may not be detected.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Clear the hotkey to capture only from the menu bar icon.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400, alignment: .topLeading)
    }
}
