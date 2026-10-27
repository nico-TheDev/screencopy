import CoreGraphics

/// Pure geometry for turning a dragged box (points, top left origin, display local)
/// into pixels of a display snapshot. No screen needed, so it is fully testable.
public enum RegionCropper {
    /// A box smaller than this on either side is treated as a stray click.
    public static let minimumSide: CGFloat = 4

    public static func isUsable(_ selection: CGRect) -> Bool {
        selection.width >= minimumSide && selection.height >= minimumSide
    }

    /// Selection times scale, min edges floored and max edges ceiled so no wanted pixel is lost,
    /// then clamped to `bounds`. Returns `.zero` when nothing remains.
    public static func pixelRect(for selection: CGRect, scale: CGFloat, bounds: CGRect) -> CGRect {
        let box = selection.standardized
        guard scale > 0, scale.isFinite, !box.isNull, !box.isInfinite else { return .zero }
        let minX = (box.minX * scale).rounded(.down)
        let minY = (box.minY * scale).rounded(.down)
        let maxX = (box.maxX * scale).rounded(.up)
        let maxY = (box.maxY * scale).rounded(.up)
        let clamped = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).intersection(bounds)
        return clamped.isNull || clamped.isEmpty ? .zero : clamped
    }

    /// Cuts the selection out of `image` and redraws it into a fresh bitmap, so the result
    /// does not keep the whole display snapshot alive. `nil` when nothing remains.
    public static func crop(_ image: CGImage, selection: CGRect, displaySize: CGSize) -> CGImage? {
        guard displaySize.width > 0 else { return nil }
        let scale = CGFloat(image.width) / displaySize.width
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = pixelRect(for: selection, scale: scale, bounds: bounds)
        guard !rect.isEmpty, let piece = image.cropping(to: rect) else { return nil }
        return redraw(piece)
    }

    private static func redraw(_ piece: CGImage) -> CGImage? {
        let space = piece.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        for candidate in [space, CGColorSpace(name: CGColorSpace.sRGB)] {
            guard let candidate,
                let context = CGContext(
                    data: nil, width: piece.width, height: piece.height, bitsPerComponent: 8,
                    bytesPerRow: 0, space: candidate, bitmapInfo: bitmapInfo
                )
            else { continue }
            context.draw(piece, in: CGRect(x: 0, y: 0, width: piece.width, height: piece.height))
            return context.makeImage()
        }
        return nil
    }
}
