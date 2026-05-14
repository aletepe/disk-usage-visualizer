import XCTest
@testable import DiskUsageVisualizer

final class SystemPathsTests: XCTestCase {
    func testAllKnownExclusionsAreExcluded() {
        let excluded = [
            "/System", "/private", "/cores", "/sbin", "/Volumes",
            "/.Spotlight-V100", "/.fseventsd", "/.DocumentRevisions-V100",
            "/.TemporaryItems", "/.Trashes", "/.vol", "/.file"
        ]
        for path in excluded {
            XCTAssertTrue(
                SystemPaths.isExcluded(URL(fileURLWithPath: path)),
                "\(path) should be excluded"
            )
        }
    }

    func testCommonUserPathsAreNotExcluded() {
        let included = ["/Users", "/Applications", "/Library", "/tmp", "/opt"]
        for path in included {
            XCTAssertFalse(
                SystemPaths.isExcluded(URL(fileURLWithPath: path)),
                "\(path) should not be excluded"
            )
        }
    }

    func testSubpathOfExclusionIsNotExcluded() {
        // Exclusion is exact-match; scanner never recurses into /System so
        // /System/Library is never presented to isExcluded in practice.
        XCTAssertFalse(SystemPaths.isExcluded(URL(fileURLWithPath: "/System/Library")))
    }
}
