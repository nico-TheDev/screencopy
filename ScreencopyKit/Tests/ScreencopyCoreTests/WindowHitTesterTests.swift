import CoreGraphics
import Testing

@testable import ScreencopyCore

struct WindowHitTesterTests {
    private let display = CGRect(x: 0, y: 0, width: 1000, height: 800)

    private func window(
        _ frame: CGRect, layer: Int = 0, pid: Int32 = 10
    ) -> WindowInfo {
        WindowInfo(frame: frame, layer: layer, ownerProcessID: pid)
    }

    private func rects(_ windows: [WindowInfo], on bounds: CGRect? = nil) -> [CGRect] {
        WindowHitTester.pickableRects(from: windows, displayBounds: bounds ?? display, excludingProcess: 99)
    }

    @Test func frontWindowWinsOnOverlap() {
        let front = CGRect(x: 100, y: 100, width: 300, height: 300)
        let back = CGRect(x: 50, y: 50, width: 600, height: 600)
        let list = rects([window(front), window(back)])
        #expect(WindowHitTester.window(at: CGPoint(x: 200, y: 200), in: list) == front)
        #expect(WindowHitTester.window(at: CGPoint(x: 500, y: 500), in: list) == back)
    }

    @Test func pointsOutsideEveryWindowHitNothing() {
        let list = rects([window(CGRect(x: 100, y: 100, width: 300, height: 300))])
        #expect(WindowHitTester.window(at: CGPoint(x: 900, y: 700), in: list) == nil)
        #expect(WindowHitTester.window(at: CGPoint(x: 5, y: 5), in: []) == nil)
    }

    @Test func onlyOrdinaryWindowsArePickable() {
        let frame = CGRect(x: 100, y: 100, width: 300, height: 300)
        #expect(rects([window(frame, layer: 25)]).isEmpty)
        #expect(rects([window(frame, pid: 99)]).isEmpty)
        #expect(rects([window(CGRect(x: 100, y: 100, width: 3, height: 300))]).isEmpty)
        #expect(rects([window(CGRect(x: 100, y: 100, width: 300, height: 3.9))]).isEmpty)
        #expect(rects([window(CGRect(x: 100, y: 100, width: 4, height: 4))]).count == 1)
    }

    @Test func windowsAreClippedToTheDisplay() {
        let list = rects([window(CGRect(x: 800, y: 600, width: 500, height: 500))])
        #expect(list == [CGRect(x: 800, y: 600, width: 200, height: 200)])
    }

    @Test func aSliverLeftAfterClippingIsNotPickable() {
        #expect(rects([window(CGRect(x: 998, y: 100, width: 300, height: 300))]).isEmpty)
        #expect(rects([window(CGRect(x: 2000, y: 100, width: 300, height: 300))]).isEmpty)
    }

    @Test func secondDisplayLeftOfAndAboveThePrimary() {
        // Global space: the primary display is (0,0,1000,800). A second one sits left of it and higher up.
        let second = CGRect(x: -1200, y: -300, width: 1200, height: 900)
        let spanning = window(CGRect(x: -400, y: 100, width: 800, height: 300))
        // On the second display the window runs from x 800 to the right edge (1200), y 400 to 700.
        #expect(rects([spanning], on: second) == [CGRect(x: 800, y: 400, width: 400, height: 300)])
        // On the primary it covers x 0 to 400, y 100 to 400.
        #expect(rects([spanning]) == [CGRect(x: 0, y: 100, width: 400, height: 300)])
    }
}
