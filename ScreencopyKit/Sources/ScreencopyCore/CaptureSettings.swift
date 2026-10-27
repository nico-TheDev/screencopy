import CoreGraphics
import Foundation

/// The values saved between launches. Everything has a default, so a fresh install needs no setup.
public struct CaptureSettings {
    public enum Key {
        public static let captureMode = "captureMode"
        public static let toolbarEnabled = "toolbarEnabled"
        public static let soundsEnabled = "soundsEnabled"
        static let toolbarOriginPrefix = "toolbarOrigin."
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mode: CaptureMode {
        get { defaults.string(forKey: Key.captureMode).flatMap(CaptureMode.init(rawValue:)) ?? .portion }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.captureMode) }
    }

    public var toolbarEnabled: Bool {
        get { defaults.object(forKey: Key.toolbarEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.toolbarEnabled) }
    }

    public var soundsEnabled: Bool {
        get { defaults.object(forKey: Key.soundsEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.soundsEnabled) }
    }

    /// Where the bar was left on one display, as fractions of the room it can move in. See `ToolbarPlacement`.
    public func toolbarPosition(display: CGDirectDisplayID) -> CGPoint? {
        guard let pair = defaults.array(forKey: Key.toolbarOriginPrefix + String(display)) as? [Double],
            pair.count == 2
        else { return nil }
        return CGPoint(x: pair[0], y: pair[1])
    }

    public func setToolbarPosition(_ position: CGPoint, display: CGDirectDisplayID) {
        defaults.set([Double(position.x), Double(position.y)], forKey: Key.toolbarOriginPrefix + String(display))
    }
}
