import Foundation
import Observation

@Observable
final class WorkspaceStore {
    private let fileManager = FileManager.default
    let rootPath = "/root"

    var rootURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appending(path: "GrokFS").appending(path: "fakefs")
    }

    func bootstrap() {
        try? fileManager.createDirectory(at: hostURL(for: "/root"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: hostURL(for: "/tmp"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: hostURL(for: "/mnt"), withIntermediateDirectories: true)
        let readme = hostURL(for: "/root/README.md")
        if !fileManager.fileExists(atPath: readme.path) {
            let text = """
            # GrokFS Workspace

            This directory is the app-owned fake filesystem root.
            Files created here persist between app launches.
            """
            try? text.write(to: readme, atomically: true, encoding: .utf8)
        }
    }

    func hostURL(for fakePath: String) -> URL {
        let normalized = normalize(fakePath)
        let relative = normalized.split(separator: "/").dropFirst().map(String.init)
        return relative.reduce(rootURL) { $0.appending(path: $1) }
    }

    func normalize(_ path: String, cwd: String = "/root") -> String {
        let raw = path.hasPrefix("/") ? path : "\(cwd)/\(path)"
        var components: [String] = []
        for part in raw.split(separator: "/") {
            if part == "." { continue }
            if part == ".." {
                _ = components.popLast()
            } else {
                components.append(String(part))
            }
        }
        return "/" + components.joined(separator: "/")
    }

    func list(_ fakePath: String) -> [WorkspaceItem] {
        let path = normalize(fakePath)
        let url = hostURL(for: path)
        let urls = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return WorkspaceItem(
                path: "\(path == "/" ? "" : path)/\(url.lastPathComponent)",
                name: url.lastPathComponent,
                isDirectory: values?.isDirectory ?? false,
                size: values?.fileSize ?? 0,
                modifiedAt: values?.contentModificationDate
            )
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func readText(_ fakePath: String) throws -> String {
        try String(contentsOf: hostURL(for: fakePath), encoding: .utf8)
    }

    func writeText(_ text: String, to fakePath: String) throws {
        let url = hostURL(for: fakePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func mkdir(_ fakePath: String) throws {
        try fileManager.createDirectory(at: hostURL(for: fakePath), withIntermediateDirectories: true)
    }

    func remove(_ fakePath: String) throws {
        try fileManager.removeItem(at: hostURL(for: fakePath))
    }
}

struct WorkspaceItem: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int
    let modifiedAt: Date?
}
