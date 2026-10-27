import CoreGraphics

/// One on screen window as the system lists it. Bounds are global points with a top left origin on the
/// primary display. There is deliberately no name field: window names are never read.
public struct WindowInfo: Sendable, Equatable {
    public let frame: CGRect
    public let layer: Int
    public let ownerProcessID: Int32

    public init(frame: CGRect, layer: Int, ownerProcessID: Int32) {
        self.frame = frame
        self.layer = layer
        self.ownerProcessID = ownerProcessID
    }
}

/// Pure geometry for window mode: which windows can be picked, where they sit on one display, and which one
/// is under the mouse.
public enum WindowHitTester {
    /// A window smaller than this on either side is not pickable.
    public static let minimumSide: CGFloat = 4

    /// Pickable windows as display local rects (top left origin), front to back, clipped to the display.
    /// `displayBounds` is the display's rectangle in the same global space as the window frames.
    public static func pickableRects(
        from windows: [WindowInfo], displayBounds: CGRect, excludingProcess: Int32
    ) -> [CGRect] {
        let displayRect = CGRect(origin: .zero, size: displayBounds.size)
        return windows.compactMap { window in
            guard window.layer == 0, window.ownerProcessID != excludingProcess,
                window.frame.width >= minimumSide, window.frame.height >= minimumSide
            else { return nil }
            let local = window.frame.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY)
            let clipped = local.intersection(displayRect)
            guard !clipped.isNull, clipped.width >= minimumSide, clipped.height >= minimumSide else { return nil }
            return clipped
        }
    }

    /// The front most rect that contains `point`, or nil when nothing is pickable there.
    public static func window(at point: CGPoint, in rects: [CGRect]) -> CGRect? {
        rects.first { $0.contains(point) }
    }
}
