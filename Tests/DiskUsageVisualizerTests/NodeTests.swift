import XCTest
@testable import DiskUsageVisualizer

final class NodeTests: XCTestCase {
    private func node(_ name: String, size: Int64, isDir: Bool = true, depth: Int = 0, parent: Node? = nil) -> Node {
        let n = Node(url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: isDir, depth: depth, parent: parent)
        n.totalSize = size
        return n
    }

    func testSortChildrenDescendingBySize() {
        let root = node("root", size: 300)
        let a = node("a", size: 100, depth: 1, parent: root)
        let b = node("b", size: 200, depth: 1, parent: root)
        let c = node("c", size: 50, depth: 1, parent: root)
        root.children = [a, b, c]

        root.sortChildrenRecursively()

        XCTAssertEqual(root.children.map(\.name), ["b", "a", "c"])
    }

    func testSortIsRecursive() {
        let root = node("root", size: 300)
        let sub = node("sub", size: 300, depth: 1, parent: root)
        root.children = [sub]
        let x = node("x", size: 10, depth: 2, parent: sub)
        let y = node("y", size: 30, depth: 2, parent: sub)
        sub.children = [x, y]

        root.sortChildrenRecursively()

        XCTAssertEqual(sub.children.map(\.name), ["y", "x"])
    }

    func testSortEmptyChildrenDoesNotCrash() {
        let root = node("root", size: 0)
        root.sortChildrenRecursively()
        XCTAssertTrue(root.children.isEmpty)
    }

    func testPathMatchesURL() {
        let n = node("foo", size: 0)
        XCTAssertEqual(n.path, "/tmp/foo")
    }

    func testParentReferenceIsWeak() {
        let root = node("root", size: 100)
        let child = Node(url: URL(fileURLWithPath: "/tmp/child"), name: "child", isDirectory: false, depth: 1, parent: root)
        XCTAssertTrue(child.parent === root)
    }
}
