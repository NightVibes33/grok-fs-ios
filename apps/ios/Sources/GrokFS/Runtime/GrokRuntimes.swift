import Foundation

enum GrokRuntimeError: LocalizedError {
    case invalidEndpoint
    case missingAPIKey
    case invalidResponse
    case server(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Enter a valid xAI API endpoint in Settings."
        case .missingAPIKey: "Enter an xAI API key in Settings."
        case .invalidResponse: "The xAI API returned an invalid response."
        case let .server(status, message): "xAI API error \(status): \(message)"
        case .emptyResponse: "The xAI API returned an empty response."
        }
    }
}

struct GrokAPIRuntime: AgentRuntime {
    let endpoint: URL?
    let apiKey: String?
    let model: String

    func send(_ prompt: String, cwd: String) async throws -> AsyncThrowingStream<AgentEvent, Error> {
        guard let endpoint else { throw GrokRuntimeError.invalidEndpoint }
        guard let apiKey, !apiKey.isEmpty else { throw GrokRuntimeError.missingAPIKey }

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    var request = URLRequest(url: chatCompletionsURL(from: endpoint))
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 120

                    let payload = ChatCompletionRequest(
                        model: model,
                        messages: [
                            APIMessage(
                                role: "system",
                                content: """
                                You are Grok inside GrokFS, an iOS coding workspace. The current fake filesystem directory is \(cwd). \
                                Be concise. When the user needs a local operation, give a shell command prefixed with $ so they can run it.
                                """
                            ),
                            APIMessage(role: "user", content: prompt)
                        ],
                        stream: false
                    )
                    request.httpBody = try JSONEncoder().encode(payload)

                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw GrokRuntimeError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let detail = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message)
                            ?? String(data: data, encoding: .utf8)
                            ?? "Unknown error"
                        throw GrokRuntimeError.server(status: http.statusCode, message: detail)
                    }

                    let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                    guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
                        throw GrokRuntimeError.emptyResponse
                    }
                    continuation.yield(AgentEvent(kind: .text, text: text))
                    continuation.yield(AgentEvent(kind: .done, text: ""))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func chatCompletionsURL(from endpoint: URL) -> URL {
        if endpoint.path.hasSuffix("/chat/completions") { return endpoint }
        if endpoint.path.hasSuffix("/v1") {
            return endpoint.appending(path: "chat/completions")
        }
        return endpoint.appending(path: "v1").appending(path: "chat/completions")
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: APIMessage
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
