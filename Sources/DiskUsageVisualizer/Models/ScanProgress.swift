import Foundation
import Observation

@Observable
@MainActor
final class ScanProgress {
    var bytesScanned: Int64 = 0
    var filesScanned: Int = 0
    var currentPath: String = ""
    var isScanning: Bool = false
    var startedAt: Date?
    var error: String?

    func reset() {
        bytesScanned = 0
        filesScanned = 0
        currentPath = ""
        isScanning = false
        startedAt = nil
        error = nil
    }

    func begin() {
        reset()
        isScanning = true
        startedAt = Date()
    }

    func finish(error: String? = nil) {
        isScanning = false
        self.error = error
    }
}
