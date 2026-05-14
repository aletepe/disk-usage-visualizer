import Foundation

struct ScanOptions: Sendable {
    var crossVolumes: Bool = false
    var dedupHardlinks: Bool = true
    var excludeRootSystemPaths: Bool = true
    var followSymlinks: Bool = false
}

final class InodeSet: @unchecked Sendable {
    private var seen = Set<AnyHashable>()
    private let lock = NSLock()
    func tryAdd(_ id: AnyHashable) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return seen.insert(id).inserted
    }
}

final class Scanner: @unchecked Sendable {
    private static let resourceKeys: Set<URLResourceKey> = [
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .volumeIdentifierKey,
        .fileResourceIdentifierKey,
        .nameKey
    ]
    private static let resourceKeysArray = Array(resourceKeys)

    let options: ScanOptions
    private let progress: ScanProgress
    private let inodes = InodeSet()
    private var rootVolumeID: AnyHashable?
    private var progressBuffer = ProgressBuffer()

    init(options: ScanOptions, progress: ScanProgress) {
        self.options = options
        self.progress = progress
    }

    func scan(root: URL) async throws -> Node {
        let standardizedRoot = root.standardizedFileURL
        await MainActor.run { progress.begin() }

        if let vals = try? standardizedRoot.resourceValues(forKeys: Self.resourceKeys),
           let vid = vals.volumeIdentifier as? AnyHashable {
            rootVolumeID = vid
        }

        let rootName: String = {
            let n = standardizedRoot.lastPathComponent
            return n.isEmpty ? standardizedRoot.path : n
        }()
        let rootNode = Node(url: standardizedRoot, name: rootName, isDirectory: true, depth: 0, parent: nil)

        do {
            try await walkRootParallel(rootNode)
            rootNode.sortChildrenRecursively()
            await flushProgress(force: true)
            await MainActor.run { progress.finish() }
        } catch is CancellationError {
            await MainActor.run { progress.finish(error: "Cancelled") }
            throw CancellationError()
        } catch {
            await MainActor.run { progress.finish(error: error.localizedDescription) }
            throw error
        }
        return rootNode
    }

    private func walkRootParallel(_ root: Node) async throws {
        let (subdirs, fileBytes, fileCount) = try readDirectory(node: root)
        root.ownSize = fileBytes
        await pushProgress(bytes: fileBytes, files: fileCount, path: root.path)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sub in subdirs {
                group.addTask { [weak self] in
                    try await self?.walkSequential(sub)
                }
            }
            try await group.waitForAll()
        }

        var total = root.ownSize
        for c in root.children { total += c.totalSize }
        root.totalSize = total
    }

    private func walkSequential(_ node: Node) async throws {
        try Task.checkCancellation()
        let (subdirs, fileBytes, fileCount) = try readDirectory(node: node)
        node.ownSize = fileBytes
        if fileCount > 0 || node.depth <= 2 {
            await pushProgress(bytes: fileBytes, files: fileCount, path: node.path)
        } else {
            await pushProgress(bytes: fileBytes, files: fileCount, path: nil)
        }
        for sub in subdirs {
            try await walkSequential(sub)
        }
        var total = node.ownSize
        for c in node.children { total += c.totalSize }
        node.totalSize = total
    }

    private func readDirectory(node: Node) throws -> (subdirs: [Node], fileBytes: Int64, fileCount: Int) {
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: node.url,
                includingPropertiesForKeys: Self.resourceKeysArray,
                options: []
            )
        } catch {
            return ([], 0, 0)
        }

        var subdirs: [Node] = []
        var fileBytes: Int64 = 0
        var fileCount = 0

        for entry in entries {
            if options.excludeRootSystemPaths && SystemPaths.isExcluded(entry) { continue }

            let vals = try? entry.resourceValues(forKeys: Self.resourceKeys)

            if !options.followSymlinks, vals?.isSymbolicLink == true { continue }

            if !options.crossVolumes,
               let vid = vals?.volumeIdentifier as? AnyHashable,
               let rid = rootVolumeID,
               vid != rid {
                continue
            }

            let isDir = vals?.isDirectory ?? false
            let name = vals?.name ?? entry.lastPathComponent

            if isDir {
                let child = Node(url: entry, name: name, isDirectory: true, depth: node.depth + 1, parent: node)
                node.children.append(child)
                subdirs.append(child)
            } else {
                if options.dedupHardlinks, let identAny = vals?.fileResourceIdentifier {
                    let ident = AnyHashable(ObjectIdentifierWrapper(identAny))
                    if !inodes.tryAdd(ident) { continue }
                }
                let bytes = Int64(vals?.totalFileAllocatedSize ?? vals?.fileSize ?? 0)
                fileBytes += bytes
                fileCount += 1
            }
        }
        return (subdirs, fileBytes, fileCount)
    }

    private actor ProgressBuffer {
        var pendingBytes: Int64 = 0
        var pendingFiles: Int = 0
        var pendingPath: String?
        var lastFlush: Date = .distantPast

        func add(bytes: Int64, files: Int, path: String?) -> (bytes: Int64, files: Int, path: String?)? {
            pendingBytes += bytes
            pendingFiles += files
            if let path { pendingPath = path }
            let now = Date()
            if now.timeIntervalSince(lastFlush) > 0.1 {
                let snap = (pendingBytes, pendingFiles, pendingPath)
                pendingBytes = 0
                pendingFiles = 0
                pendingPath = nil
                lastFlush = now
                return snap
            }
            return nil
        }

        func drain() -> (bytes: Int64, files: Int, path: String?) {
            let snap = (pendingBytes, pendingFiles, pendingPath)
            pendingBytes = 0
            pendingFiles = 0
            pendingPath = nil
            lastFlush = Date()
            return snap
        }
    }

    private func pushProgress(bytes: Int64, files: Int, path: String?) async {
        if let snap = await progressBuffer.add(bytes: bytes, files: files, path: path) {
            await MainActor.run {
                progress.bytesScanned += snap.bytes
                progress.filesScanned += snap.files
                if let p = snap.path { progress.currentPath = p }
            }
        }
    }

    private func flushProgress(force: Bool) async {
        let snap = await progressBuffer.drain()
        await MainActor.run {
            progress.bytesScanned += snap.bytes
            progress.filesScanned += snap.files
            if let p = snap.path { progress.currentPath = p }
        }
    }
}

private struct ObjectIdentifierWrapper: Hashable {
    let object: AnyObject
    init(_ obj: Any) {
        self.object = obj as AnyObject
    }
    static func == (lhs: ObjectIdentifierWrapper, rhs: ObjectIdentifierWrapper) -> Bool {
        if let l = lhs.object as? NSObject, let r = rhs.object as? NSObject {
            return l.isEqual(r)
        }
        return ObjectIdentifier(lhs.object) == ObjectIdentifier(rhs.object)
    }
    func hash(into hasher: inout Hasher) {
        if let n = object as? NSObject {
            hasher.combine(n.hash)
        } else {
            hasher.combine(ObjectIdentifier(object))
        }
    }
}
