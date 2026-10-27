import CoreGraphics
import Testing

@testable import ScreencopyCore

/// Stands in for ScreenCaptureKit: returns canned pictures or a canned error.
struct FakeScreenCapturer: ScreenCapturing {
    var result: Result<[DisplaySnapshot], ScreencopyError>

    func snapshot(displays: [CGDirectDisplayID]) async throws -> [DisplaySnapshot] {
        try result.get().filter { displays.contains($0.displayID) }
    }
}

@Suite struct FakeScreenCapturerTests {
    @Test func snapshotThenCropGivesTheBoxedPixels() async throws {
        let image = try #require(makeCoordinateImage(width: 80, height: 40))
        let fake = FakeScreenCapturer(
            result: .success([DisplaySnapshot(displayID: 7, image: image, pointSize: CGSize(width: 40, height: 20))]))
        let snapshots = try await fake.snapshot(displays: [7])
        let shot = try #require(snapshots.first)
        let cropped = try #require(
            RegionCropper.crop(
                shot.image, selection: CGRect(x: 5, y: 5, width: 10, height: 5), displaySize: shot.pointSize))
        #expect(cropped.width == 20 && cropped.height == 10)
    }

    @Test func failureIsPassedThrough() async {
        let fake = FakeScreenCapturer(result: .failure(.permissionDenied))
        await #expect(throws: ScreencopyError.permissionDenied) {
            _ = try await fake.snapshot(displays: [1])
        }
    }
}
