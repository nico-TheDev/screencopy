/// How the user picks the pixels to read. The raw value is what gets saved.
public enum CaptureMode: String, Sendable, CaseIterable, Equatable {
    case portion
    case screen
    case window

    /// The key that switches to this mode while the capture is open.
    public var key: Character {
        switch self {
        case .portion: "1"
        case .screen: "2"
        case .window: "3"
        }
    }

    public init?(key: Character) {
        guard let mode = Self.allCases.first(where: { $0.key == key }) else { return nil }
        self = mode
    }

    public var hint: String {
        switch self {
        case .portion: "Drag to select, Esc to cancel"
        case .screen: "Click a screen to capture it"
        case .window: "Click a window to capture it"
        }
    }
}
