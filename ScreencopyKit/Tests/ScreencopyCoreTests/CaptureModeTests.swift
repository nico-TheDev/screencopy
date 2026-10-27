import Testing

@testable import ScreencopyCore

struct CaptureModeTests {
    @Test func keysMapToModes() {
        #expect(CaptureMode(key: "1") == .portion)
        #expect(CaptureMode(key: "2") == .screen)
        #expect(CaptureMode(key: "3") == .window)
        #expect(CaptureMode(key: "4") == nil)
        #expect(CaptureMode(key: "a") == nil)
    }

    @Test func everyModeRoundTripsThroughItsKeyAndRawValue() {
        for mode in CaptureMode.allCases {
            #expect(CaptureMode(key: mode.key) == mode)
            #expect(CaptureMode(rawValue: mode.rawValue) == mode)
        }
    }

    @Test func hintsAreFixed() {
        #expect(CaptureMode.portion.hint == "Drag to select, Esc to cancel")
        #expect(CaptureMode.screen.hint == "Click a screen to capture it")
        #expect(CaptureMode.window.hint == "Click a window to capture it")
    }
}
