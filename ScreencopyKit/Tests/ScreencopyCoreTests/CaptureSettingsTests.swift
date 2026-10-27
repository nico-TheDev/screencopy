import CoreGraphics
import Foundation
import Testing

@testable import ScreencopyCore

struct CaptureSettingsTests {
    private func makeSettings() -> CaptureSettings {
        let name = "CaptureSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return CaptureSettings(defaults: defaults)
    }

    @Test func freshInstallUsesTheDefaults() {
        let settings = makeSettings()
        #expect(settings.mode == .portion)
        #expect(settings.toolbarEnabled)
        #expect(settings.soundsEnabled)
        #expect(settings.toolbarPosition(display: 1) == nil)
    }

    @Test func changesAreSaved() {
        let settings = makeSettings()
        settings.mode = .window
        settings.toolbarEnabled = false
        settings.soundsEnabled = false
        #expect(settings.mode == .window)
        #expect(!settings.toolbarEnabled)
        #expect(!settings.soundsEnabled)
    }

    @Test func anUnknownSavedModeFallsBackToPortion() {
        let name = "CaptureSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.set("bogus", forKey: CaptureSettings.Key.captureMode)
        #expect(CaptureSettings(defaults: defaults).mode == .portion)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func positionsAreKeptPerDisplay() {
        let settings = makeSettings()
        settings.setToolbarPosition(CGPoint(x: 0.25, y: 0.75), display: 7)
        #expect(settings.toolbarPosition(display: 7) == CGPoint(x: 0.25, y: 0.75))
        #expect(settings.toolbarPosition(display: 8) == nil)
    }
}
