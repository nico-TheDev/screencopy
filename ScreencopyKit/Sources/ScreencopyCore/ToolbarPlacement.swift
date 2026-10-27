import CoreGraphics

/// Where the capture bar sits on a display. All frames are Cocoa space (bottom left origin), and `visible`
/// is the display's visible frame, so the bar stays clear of the Dock and menu bar.
public enum ToolbarPlacement {
    public static let size = CGSize(width: 300, height: 44)
    public static let bottomGap: CGFloat = 48

    /// Centred horizontally, `bottomGap` above the bottom of the visible area.
    public static func defaultFrame(in visible: CGRect) -> CGRect {
        CGRect(
            x: visible.midX - size.width / 2, y: visible.minY + bottomGap,
            width: size.width, height: size.height)
    }

    /// The saved spot, or the default one when there is none, it is not usable, or the bar does not fit.
    /// `saved` holds fractions (0 to 1) of the room the bar can move in, so a resolution change keeps it sensible.
    public static func frame(in visible: CGRect, saved: CGPoint?) -> CGRect {
        let roomX = visible.width - size.width
        let roomY = visible.height - size.height
        guard let saved, roomX > 0, roomY > 0,
            (0...1).contains(saved.x), (0...1).contains(saved.y)
        else { return defaultFrame(in: visible) }
        return CGRect(
            x: visible.minX + saved.x * roomX, y: visible.minY + saved.y * roomY,
            width: size.width, height: size.height)
    }

    /// Pulls a frame back so it lies fully inside `visible`.
    public static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX), max(visible.maxX - result.width, visible.minX))
        result.origin.y = min(max(result.minY, visible.minY), max(visible.maxY - result.height, visible.minY))
        return result
    }

    /// The fractions to save for a frame the user left at this spot. nil when the display is too small to move in.
    public static func position(of frame: CGRect, in visible: CGRect) -> CGPoint? {
        let roomX = visible.width - size.width
        let roomY = visible.height - size.height
        guard roomX > 0, roomY > 0 else { return nil }
        let fixed = clamped(frame, to: visible)
        return CGPoint(x: (fixed.minX - visible.minX) / roomX, y: (fixed.minY - visible.minY) / roomY)
    }
}
