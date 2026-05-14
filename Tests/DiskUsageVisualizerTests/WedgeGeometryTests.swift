import XCTest
import SwiftUI
@testable import DiskUsageVisualizer

final class WedgeGeometryTests: XCTestCase {
    private func makeTree(aSize: Int64 = 60, bSize: Int64 = 40) -> Node {
        let root = Node(url: URL(fileURLWithPath: "/"), name: "/", isDirectory: true, depth: 0, parent: nil)
        root.totalSize = aSize + bSize
        let a = Node(url: URL(fileURLWithPath: "/a"), name: "a", isDirectory: false, depth: 1, parent: root)
        a.totalSize = aSize
        let b = Node(url: URL(fileURLWithPath: "/b"), name: "b", isDirectory: false, depth: 1, parent: root)
        b.totalSize = bSize
        root.children = [a, b]
        return root
    }

    func testRootLayoutCoversFullCircle() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 3, minAngle: 0)
        let root = layouts.first { $0.ringIndex == 0 }!
        XCTAssertEqual(root.startAngle, 0, accuracy: 1e-10)
        XCTAssertEqual(root.endAngle, WedgeGeometry.twoPi, accuracy: 1e-10)
    }

    func testChildCountInRing1() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 3, minAngle: 0)
        XCTAssertEqual(layouts.filter { $0.ringIndex == 1 }.count, 2)
    }

    func testChildAnglesSumToFullCircle() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 3, minAngle: 0)
        let ring1 = layouts.filter { $0.ringIndex == 1 }
        let total = ring1.reduce(0.0) { $0 + ($1.endAngle - $1.startAngle) }
        XCTAssertEqual(total, WedgeGeometry.twoPi, accuracy: 1e-10)
    }

    func testChildAnglesAreProportionalToSize() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(aSize: 60, bSize: 40), maxRings: 3, minAngle: 0)
        let spans = layouts.filter { $0.ringIndex == 1 }.map { $0.endAngle - $0.startAngle }
        let maxSpan = spans.max()!
        XCTAssertEqual(maxSpan / WedgeGeometry.twoPi, 0.6, accuracy: 1e-10)
    }

    func testMinAngleCullsSmallWedges() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 3, minAngle: 4 * Double.pi)
        XCTAssertEqual(layouts.filter { $0.ringIndex == 1 }.count, 0)
    }

    func testMaxRingsLimitsRingDepth() {
        let root = Node(url: URL(fileURLWithPath: "/"), name: "/", isDirectory: true, depth: 0, parent: nil)
        root.totalSize = 100
        let sub = Node(url: URL(fileURLWithPath: "/sub"), name: "sub", isDirectory: true, depth: 1, parent: root)
        sub.totalSize = 100
        root.children = [sub]
        let leaf = Node(url: URL(fileURLWithPath: "/sub/leaf"), name: "leaf", isDirectory: true, depth: 2, parent: sub)
        leaf.totalSize = 100
        sub.children = [leaf]

        let layouts = WedgeGeometry.computeLayouts(focusedRoot: root, maxRings: 2, minAngle: 0)
        XCTAssertEqual(layouts.filter { $0.ringIndex >= 2 }.count, 0)
    }

    func testEmptyTreeProducesOnlyRootLayout() {
        let root = Node(url: URL(fileURLWithPath: "/"), name: "/", isDirectory: true, depth: 0, parent: nil)
        root.totalSize = 0
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: root, maxRings: 3, minAngle: 0)
        XCTAssertEqual(layouts.count, 1)
        XCTAssertEqual(layouts[0].ringIndex, 0)
    }

    func testHitTestAtCenterReturnsRing0() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 3, minAngle: 0)
        let center = CGPoint(x: 200, y: 200)
        let hit = WedgeGeometry.hitTest(layouts: layouts, at: center, center: center, innerRadius: 36, ringWidth: 50)
        XCTAssertEqual(hit?.ringIndex, 0)
    }

    func testHitTestFarOutsideReturnsNil() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 2, minAngle: 0)
        let hit = WedgeGeometry.hitTest(layouts: layouts, at: CGPoint(x: 1000, y: 1000), center: CGPoint(x: 100, y: 100), innerRadius: 36, ringWidth: 50)
        XCTAssertNil(hit)
    }

    func testWedgeColorDoesNotCrash() {
        let layouts = WedgeGeometry.computeLayouts(focusedRoot: makeTree(), maxRings: 4, minAngle: 0)
        for layout in layouts where layout.ringIndex > 0 {
            _ = WedgeGeometry.wedgeColor(for: layout)
        }
    }
}
