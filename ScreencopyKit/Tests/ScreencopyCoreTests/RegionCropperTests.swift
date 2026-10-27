import Foundation
import CoreGraphics
import Testing

@testable import ScreencopyCore

/// Builds an image where the red byte of each pixel is its x and the green byte is its y,
/// so a crop can be checked pixel by pixel.
func makeCoordinateImage(width: Int, height: Int) -> CGImage? {
    var bytes = [UInt8]()
    bytes.reserveCapacity(width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            bytes += [UInt8(x % 256), UInt8(y % 256), 0, 255]
        }
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
        let space = CGColorSpace(name: CGColorSpace.sRGB)
    else { return nil }
    return CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )
}

/// Returns (red, green) of one pixel.
func pixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8)? {
    var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
        guard
            let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard drawn else { return nil }
    let offset = (y * image.width + x) * 4
    return (buffer[offset], buffer[offset + 1])
}

@Suite struct RegionCropperTests {
    let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)

    @Test func scaleOneKeepsPoints() {
        let rect = RegionCropper.pixelRect(for: CGRect(x: 10, y: 20, width: 50, height: 30), scale: 1, bounds: bounds)
        #expect(rect == CGRect(x: 10, y: 20, width: 50, height: 30))
    }

    @Test func scaleTwoDoublesEverything() {
        let rect = RegionCropper.pixelRect(for: CGRect(x: 10, y: 20, width: 30, height: 10), scale: 2, bounds: bounds)
        #expect(rect == CGRect(x: 20, y: 40, width: 60, height: 20))
    }

    @Test func boxAtTheOrigin() {
        let rect = RegionCropper.pixelRect(for: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 2, bounds: bounds)
        #expect(rect == CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    @Test func boxTouchingTheFarEdge() {
        let rect = RegionCropper.pixelRect(for: CGRect(x: 90, y: 40, width: 10, height: 10), scale: 1, bounds: bounds)
        #expect(rect == CGRect(x: 90, y: 40, width: 10, height: 10))
        let far = RegionCropper.pixelRect(for: CGRect(x: 190, y: 90, width: 10, height: 10), scale: 1, bounds: bounds)
        #expect(far.maxX == 200 && far.maxY == 100)
    }

    @Test func backwardsDragGivesTheSameBox() {
        let forward = CGRect(x: 10, y: 10, width: 40, height: 20)
        let backward = CGRect(x: 50, y: 30, width: -40, height: -20)
        #expect(
            RegionCropper.pixelRect(for: backward, scale: 2, bounds: bounds)
                == RegionCropper.pixelRect(for: forward, scale: 2, bounds: bounds))
    }

    @Test func fractionalEdgesRoundOutward() {
        let rect = RegionCropper.pixelRect(
            for: CGRect(x: 10.4, y: 10.4, width: 10, height: 10), scale: 1, bounds: bounds)
        #expect(rect == CGRect(x: 10, y: 10, width: 11, height: 11))
    }

    @Test func boxIsClampedToTheImage() {
        let rect = RegionCropper.pixelRect(
            for: CGRect(x: 150, y: 80, width: 100, height: 100), scale: 1, bounds: bounds)
        #expect(rect == CGRect(x: 150, y: 80, width: 50, height: 20))
    }

    @Test func nothingLeftGivesZero() {
        let outside = RegionCropper.pixelRect(
            for: CGRect(x: 500, y: 500, width: 10, height: 10), scale: 1, bounds: bounds)
        #expect(outside == .zero)
        let empty = RegionCropper.pixelRect(for: .zero, scale: 1, bounds: bounds)
        #expect(empty == .zero)
        let badScale = RegionCropper.pixelRect(for: CGRect(x: 0, y: 0, width: 5, height: 5), scale: 0, bounds: bounds)
        #expect(badScale == .zero)
    }

    @Test func usableNeedsFourPointsOnBothSides() {
        #expect(RegionCropper.isUsable(CGRect(x: 0, y: 0, width: 4, height: 4)))
        #expect(!RegionCropper.isUsable(CGRect(x: 0, y: 0, width: 3.9, height: 50)))
        #expect(!RegionCropper.isUsable(CGRect(x: 0, y: 0, width: 50, height: 3)))
        #expect(!RegionCropper.isUsable(.zero))
    }

    @Test func cropHasNativePixelSizeAndContent() throws {
        // A 2x display: 100x50 points is a 200x100 pixel snapshot.
        let image = try #require(makeCoordinateImage(width: 200, height: 100))
        let cropped = try #require(
            RegionCropper.crop(
                image, selection: CGRect(x: 10, y: 5, width: 20, height: 10),
                displaySize: CGSize(width: 100, height: 50)))
        #expect(cropped.width == 40)
        #expect(cropped.height == 20)
        let first = try #require(pixel(cropped, x: 0, y: 0))
        #expect(first == (20, 10))
        let last = try #require(pixel(cropped, x: 39, y: 19))
        #expect(last == (59, 29))
    }

    @Test func cropOnScaleOneDisplay() throws {
        let image = try #require(makeCoordinateImage(width: 100, height: 50))
        let cropped = try #require(
            RegionCropper.crop(
                image, selection: CGRect(x: 30, y: 20, width: 10, height: 5),
                displaySize: CGSize(width: 100, height: 50)))
        #expect(cropped.width == 10 && cropped.height == 5)
        let first = try #require(pixel(cropped, x: 0, y: 0))
        #expect(first == (30, 20))
    }

    @Test func cropOfNothingIsNil() throws {
        let image = try #require(makeCoordinateImage(width: 100, height: 50))
        #expect(RegionCropper.crop(image, selection: .zero, displaySize: CGSize(width: 100, height: 50)) == nil)
        #expect(
            RegionCropper.crop(image, selection: CGRect(x: 0, y: 0, width: 5, height: 5), displaySize: .zero) == nil)
    }
}
