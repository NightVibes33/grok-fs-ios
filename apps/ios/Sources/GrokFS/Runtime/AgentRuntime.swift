import Foundation

@MainActor
protocol AgentRuntime {
    func send(_ prompt: String, cwd: String, sessionID: UUID) async throws -> AsyncThrowingStream<AgentEvent, Error>
}

struct AgentEvent: Equatable {
    enum Kind: Equatable {
        case text
        case tool
        case done
    }

    let kind: Kind
    let text: String
}

struct LocalShellAgentRuntime: AgentRuntime {
    let shell: FakeFSShell

    func send(_ prompt: String, cwd: String, sessionID: UUID) async throws -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("$") {
                    let command = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(AgentEvent(kind: .tool, text: "$ \(command)\n"))
                    let result = try await EmbeddedIshRuntime.shared.run(command, cwd: cwd)
                    continuation.yield(AgentEvent(kind: .text, text: result.output))
                    if result.exitCode != 0 {
                        continuation.yield(AgentEvent(kind: .text, text: "\nexit \(result.exitCode)"))
                    }
                } else {
                    let response = """
                    Grok CLI is not enabled in this build yet.

                    Current runtime: local fakefs shell.
                    Try `$ ls /root`, `$ pwd`, or `$ echo hello > /root/hello.txt`.
                    """
                    for line in response.split(separator: "\n", omittingEmptySubsequences: false) {
                        continuation.yield(AgentEvent(kind: .text, text: String(line) + "\n"))
                        try? await Task.sleep(for: .milliseconds(35))
                    }
                }
                continuation.yield(AgentEvent(kind: .done, text: ""))
                continuation.finish()
            }
        }
    }
}
