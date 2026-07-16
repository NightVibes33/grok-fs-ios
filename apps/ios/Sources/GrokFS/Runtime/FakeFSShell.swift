import Foundation

struct ShellResult: Equatable {
    let exitCode: Int32
    let output: String
}

final class FakeFSShell {
    let workspace: WorkspaceStore

    init(workspace: WorkspaceStore) {
        self.workspace = workspace
    }

    func run(_ command: String, cwd: String) -> ShellResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ShellResult(exitCode: 0, output: "") }

        let parts = split(trimmed)
        guard let executable = parts.first else { return ShellResult(exitCode: 0, output: "") }
        let args = Array(parts.dropFirst())

        do {
            switch executable {
            case "pwd":
                return ShellResult(exitCode: 0, output: workspace.normalize(cwd) + "\n")
            case "ls":
                let target = args.first ?? cwd
                let items = workspace.list(workspace.normalize(target, cwd: cwd))
                let output = items.map { $0.isDirectory ? "\($0.name)/" : $0.name }.joined(separator: "\n")
                return ShellResult(exitCode: 0, output: output.isEmpty ? "" : output + "\n")
            case "cat":
                guard let path = args.first else { return ShellResult(exitCode: 2, output: "cat: missing path\n") }
                return ShellResult(exitCode: 0, output: try workspace.readText(workspace.normalize(path, cwd: cwd)))
            case "mkdir":
                guard let path = args.last else { return ShellResult(exitCode: 2, output: "mkdir: missing operand\n") }
                try workspace.mkdir(workspace.normalize(path, cwd: cwd))
                return ShellResult(exitCode: 0, output: "")
            case "rm":
                guard let path = args.last else { return ShellResult(exitCode: 2, output: "rm: missing operand\n") }
                try workspace.remove(workspace.normalize(path, cwd: cwd))
                return ShellResult(exitCode: 0, output: "")
            case "echo":
                return try echo(args, cwd: cwd)
            case "grok":
                return ShellResult(exitCode: 127, output: "grok: CLI runtime is not installed in this build. Configure Grok CLI or Grok API runtime in Settings.\n")
            default:
                return ShellResult(exitCode: 127, output: "\(executable): command not found\n")
            }
        } catch {
            return ShellResult(exitCode: 1, output: "\(error.localizedDescription)\n")
        }
    }

    private func echo(_ args: [String], cwd: String) throws -> ShellResult {
        if let redirect = args.firstIndex(of: ">"), redirect + 1 < args.count {
            let text = args[..<redirect].joined(separator: " ") + "\n"
            let path = workspace.normalize(args[redirect + 1], cwd: cwd)
            try workspace.writeText(text, to: path)
            return ShellResult(exitCode: 0, output: "")
        }
        return ShellResult(exitCode: 0, output: args.joined(separator: " ") + "\n")
    }

    private func split(_ command: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        for char in command {
            if char == "'" || char == "\"" {
                if quote == char {
                    quote = nil
                } else if quote == nil {
                    quote = char
                } else {
                    current.append(char)
                }
            } else if char.isWhitespace && quote == nil {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
