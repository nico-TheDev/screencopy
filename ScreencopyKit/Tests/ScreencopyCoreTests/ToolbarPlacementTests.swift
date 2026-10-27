import CoreGraphics
import Testing

@testable import ScreencopyCore

struct ToolbarPlacementTests {
    private let visible = CGRect(x: 0, y: 80, width: 1440, height: 800)

    @Test func defaultIsCentredAndAboveTheDock() {
        let frame = ToolbarPlacement.defaultFrame(in: visible)
        #expect(frame.width == 300)
        #expect(frame.midX == visible.midX)
        #expect(frame.minY == visible.minY + 48)
    }

    @Test func noSavedSpotUsesTheDefault() {
        #expect(ToolbarPlacement.frame(in: visible, saved: nil) == ToolbarPlacement.defaultFrame(in: visible))
    }

    @Test func aSavedSpotIsRestoredAndStaysOnTheDisplay() {
        let frame = ToolbarPlacement.frame(in: visible, saved: CGPoint(x: 1, y: 1))
        #expect(visible.contains(frame))
        #expect(frame.maxX == visible.maxX)
        #expect(frame.maxY == visible.maxY)
    }

    @Test func aSavedSpotFollowsAResolutionChange() {
        let smaller = CGRect(x: 0, y: 0, width: 800, height: 600)
        let frame = ToolbarPlacement.frame(in: smaller, saved: CGPoint(x: 0.5, y: 0))
        #expect(smaller.contains(frame))
        #expect(frame.minX == (800 - 300) * 0.5)
    }

    @Test func invalidSavedSpotsFallBackToTheDefault() {
        let fallback = ToolbarPlacement.defaultFrame(in: visible)
        #expect(ToolbarPlacement.frame(in: visible, saved: CGPoint(x: -0.1, y: 0.5)) == fallback)
        #expect(ToolbarPlacement.frame(in: visible, saved: CGPoint(x: 0.5, y: 1.5)) == fallback)
        #expect(ToolbarPlacement.frame(in: visible, saved: CGPoint(x: .nan, y: 0.5)) == fallback)
    }

    @Test func aDisplayTooSmallForTheBarUsesTheDefault() {
        let tiny = CGRect(x: 0, y: 0, width: 280, height: 600)
        #expect(
            ToolbarPlacement.frame(in: tiny, saved: CGPoint(x: 0.5, y: 0.5)) == ToolbarPlacement.defaultFrame(in: tiny))
    }

    @Test func clampingKeepsTheBarFullyInside() {
        let outside = CGRect(x: -50, y: 2000, width: 300, height: 44)
        let frame = ToolbarPlacement.clamped(outside, to: visible)
        #expect(visible.contains(frame))
    }

    @Test func positionRoundTrips() throws {
        let frame = CGRect(x: 400, y: 300, width: 300, height: 44)
        let position = try #require(ToolbarPlacement.position(of: frame, in: visible))
        let restored = ToolbarPlacement.frame(in: visible, saved: position)
        #expect(abs(restored.minX - frame.minX) < 0.001)
        #expect(abs(restored.minY - frame.minY) < 0.001)
    }

    @Test func positionIsNilWhenTheBarCannotMove() {
        #expect(ToolbarPlacement.position(of: .zero, in: CGRect(x: 0, y: 0, width: 280, height: 600)) == nil)
    }
}
