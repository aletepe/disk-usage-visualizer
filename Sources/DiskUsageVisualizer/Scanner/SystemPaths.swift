import Foundation

enum SystemPaths {
    static let rootExclusions: Set<String> = [
        "/System",
        "/private",
        "/cores",
        "/sbin",
        "/Volumes",
        "/.Spotlight-V100",
        "/.fseventsd",
        "/.DocumentRevisions-V100",
        "/.TemporaryItems",
        "/.Trashes",
        "/.vol",
        "/.file"
    ]

    static func isExcluded(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.path
        return rootExclusions.contains(p)
    }

    static func canReadLibrary() -> Bool {
        let probe = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC")
        return FileManager.default.isReadableFile(atPath: probe.path)
    }
}
