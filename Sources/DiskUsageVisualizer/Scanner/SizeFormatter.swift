import Foundation

enum SizeFormatter {
    static func human(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    static func percent(_ part: Int64, of whole: Int64) -> String {
        guard whole > 0 else { return "0.0%" }
        let p = Double(part) / Double(whole) * 100.0
        return String(format: "%.1f%%", p)
    }
}
