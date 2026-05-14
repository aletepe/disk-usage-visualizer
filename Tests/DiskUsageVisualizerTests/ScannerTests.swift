import XCTest
@testable import DiskUsageVisualizer

final class ScannerTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeScanner(_ progress: ScanProgress) -> DiskUsageVisualizer.Scanner {
        DiskUsageVisualizer.Scanner(
            options: ScanOptions(crossVolumes: false, dedupHardlinks: true, excludeRootSystemPaths: false, followSymlinks: false),
            progress: progress
        )
    }

    func testScanEmptyDirectory() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let progress = await MainActor.run { ScanProgress() }
        let result = try await makeScanner(progress).scan(root: dir)

        XCTAssertEqual(result.totalSize, 0)
        XCTAssertEqual(result.children.count, 0)
        XCTAssertEqual(result.name, dir.lastPathComponent)
    }

    func testScanDirectoryChildrenAndFileBytes() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sub = dir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4096).write(to: sub.appendingPathComponent("inner.dat"))
        try Data(repeating: 2, count: 8192).write(to: dir.appendingPathComponent("root.dat"))

        let progress = await MainActor.run { ScanProgress() }
        let result = try await makeScanner(progress).scan(root: dir)

        // Files are counted in ownSize; only directories become child Nodes.
        XCTAssertEqual(result.children.count, 1)
        XCTAssertEqual(result.children[0].name, "subdir")
        XCTAssertGreaterThan(result.ownSize, 0)
        XCTAssertGreaterThan(result.children[0].totalSize, 0)
    }

    func testScanSortsChildrenByTotalSizeDescending() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        for (name, size) in [("small", 1024), ("large", 200 * 1024)] {
            let sub = dir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data(repeating: 0, count: size).write(to: sub.appendingPathComponent("f.dat"))
        }

        let progress = await MainActor.run { ScanProgress() }
        let result = try await makeScanner(progress).scan(root: dir)

        XCTAssertEqual(result.children.count, 2)
        XCTAssertGreaterThan(result.children[0].totalSize, result.children[1].totalSize)
        XCTAssertEqual(result.children[0].name, "large")
    }

    func testScanHardlinkDedup() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = dir.appendingPathComponent("original.dat")
        let payload = Data(repeating: 0xAB, count: 100 * 1024)
        try payload.write(to: original)
        try FileManager.default.linkItem(at: original, to: dir.appendingPathComponent("hardlink.dat"))

        let progress = await MainActor.run { ScanProgress() }
        let result = try await makeScanner(progress).scan(root: dir)

        // With dedup, ownSize should reflect one file, not two.
        XCTAssertLessThan(result.ownSize, Int64(payload.count) * 2)
        XCTAssertGreaterThan(result.ownSize, 0)
    }
}
