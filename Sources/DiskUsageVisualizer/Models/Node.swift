import Foundation

final class Node: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let depth: Int
    weak var parent: Node?
    var ownSize: Int64 = 0
    var totalSize: Int64 = 0
    var children: [Node] = []
    var truncated: Bool = false

    init(url: URL, name: String, isDirectory: Bool, depth: Int, parent: Node?) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.depth = depth
        self.parent = parent
    }

    var path: String { url.path }

    func sortChildrenRecursively() {
        children.sort { $0.totalSize > $1.totalSize }
        for c in children { c.sortChildrenRecursively() }
    }
}
