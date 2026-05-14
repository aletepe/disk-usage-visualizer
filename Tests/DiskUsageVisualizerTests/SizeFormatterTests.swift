import XCTest
@testable import DiskUsageVisualizer

final class SizeFormatterTests: XCTestCase {
    func testHumanZeroIsNonEmpty() {
        XCTAssertFalse(SizeFormatter.human(0).isEmpty)
    }

    func testHumanNegativeClampedToZero() {
        XCTAssertEqual(SizeFormatter.human(-1), SizeFormatter.human(0))
    }

    func testHumanKilobytes() {
        let s = SizeFormatter.human(1_024)
        XCTAssertTrue(s.contains("KB") || s.contains("kB"), s)
    }

    func testHumanMegabytes() {
        let s = SizeFormatter.human(1_048_576)
        XCTAssertTrue(s.contains("MB"), s)
    }

    func testHumanGigabytes() {
        let s = SizeFormatter.human(1_073_741_824)
        XCTAssertTrue(s.contains("GB"), s)
    }

    func testPercentZeroWhole() {
        XCTAssertEqual(SizeFormatter.percent(100, of: 0), "0.0%")
    }

    func testPercentHalf() {
        XCTAssertEqual(SizeFormatter.percent(1, of: 2), "50.0%")
    }

    func testPercentThird() {
        XCTAssertEqual(SizeFormatter.percent(1, of: 3), "33.3%")
    }

    func testPercentFull() {
        XCTAssertEqual(SizeFormatter.percent(5, of: 5), "100.0%")
    }
}
