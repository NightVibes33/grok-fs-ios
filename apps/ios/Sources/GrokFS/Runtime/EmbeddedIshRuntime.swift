import Foundation

private struct NativeIshResult {
    let exitCode: Int32
    let bytes: UnsafeMutablePointer<UInt8>?
    let length: UInt
}

@_silgen_name("grokfs_ish_bootstrap")
private func nativeIshBootstrap(
    _ archivePath: UnsafePointer<CChar>,
    _ supportPath: UnsafePointer<CChar>
) -> Int32

@_silgen_name("grokfs_ish_run")
private func nativeIshRun(
    _ command: UnsafePointer<CChar>,
    _ cwd: UnsafePointer<CChar>,
    _ timeoutMilliseconds: UInt64
) -> NativeIshResult

@_silgen_name("grokfs_ish_result_free")
private func nativeIshResultFree(_ bytes: UnsafeMutablePointer<UInt8>?, _ length: UInt)

actor EmbeddedIshRuntime {
    static let shared = EmbeddedIshRuntime()

    enum RuntimeError: LocalizedError {
        case missingRootFS
        case bootstrapFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .missingRootFS: "The bundled iSH root filesystem is missing."
            case let .bootstrapFailed(code): "The iSH runtime could not start (code \(code))."
            }
        }
    }

    private var isReady = false

    func bootstrap() throws {
        guard !isReady else { return }
        guard let archive = Bundle.main.url(forResource: "fs", withExtension: "tar.gz") else {
            throw RuntimeError.missingRootFS
        }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appending(path: "GrokFSIsh", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let code = archive.path.withCString { archivePath in
            support.path.withCString { supportPath in
                nativeIshBootstrap(archivePath, supportPath)
            }
        }
        guard code == 0 else { throw RuntimeError.bootstrapFailed(code) }
        isReady = true
    }

    func run(
        _ command: String,
        cwd: String = "/root",
        timeout: Duration = .seconds(600)
    ) throws -> ShellResult {
        try bootstrap()
        let milliseconds = UInt64(max(1, timeout.components.seconds * 1_000))
        let native = command.withCString { commandPointer in
            cwd.withCString { cwdPointer in
                nativeIshRun(commandPointer, cwdPointer, milliseconds)
            }
        }
        defer { nativeIshResultFree(native.bytes, native.length) }
        let output: String
        if let bytes = native.bytes, native.length > 0 {
            output = String(decoding: UnsafeBufferPointer(start: bytes, count: Int(native.length)), as: UTF8.self)
        } else {
            output = ""
        }
        return ShellResult(exitCode: native.exitCode, output: output)
    }
}
