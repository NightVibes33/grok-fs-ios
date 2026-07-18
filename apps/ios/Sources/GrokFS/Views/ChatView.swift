import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @State private var composer = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            messages
            Divider()
            composerBar
        }
        .navigationTitle(model.selectedThread?.title ?? "Session")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    model.newThread()
                } label: {
                    Label("New Session", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(RuntimeMode.allCases) { mode in
                        Button(mode.rawValue) {
                            model.runtimeMode = mode
                        }
                    }
                } label: {
                    Label(model.runtimeMode.rawValue, systemImage: "cpu")
                }
            }
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.selectedThread?.messages ?? []) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: model.selectedThread?.messages.count ?? 0) {
                if let id = model.selectedThread?.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message GrokFS or run `$ ls /root`", text: $composer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding()
    }

    private func send() async {
        guard var thread = model.selectedThread else { return }
        let prompt = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        composer = ""
        isSending = true

        thread.messages.append(ChatMessage(role: .user, text: prompt))
        var assistant = ChatMessage(role: .assistant, text: "", isStreaming: true)
        thread.messages.append(assistant)
        thread.updatedAt = Date()
        if thread.title == "New Session" || thread.title == "Workspace" {
            thread.title = String(prompt.prefix(32))
        }
        model.updateThread(thread)

        do {
            let stream = try await model.activeRuntime.send(prompt, cwd: thread.cwd, sessionID: thread.id)
            for try await event in stream {
                guard var current = model.selectedThread,
                      let index = current.messages.firstIndex(where: { $0.id == assistant.id }) else { continue }
                switch event.kind {
                case .done:
                    current.messages[index].isStreaming = false
                case .text:
                    current.messages[index].text += event.text
                    assistant = current.messages[index]
                case .tool:
                    if index > 0,
                       current.messages[index - 1].role == .tool {
                        current.messages[index - 1].text += event.text
                    } else {
                        current.messages.insert(ChatMessage(role: .tool, text: event.text), at: index)
                    }
                }
                current.updatedAt = Date()
                model.updateThread(current)
            }
        } catch {
            guard var current = model.selectedThread,
                  let index = current.messages.firstIndex(where: { $0.id == assistant.id }) else { return }
            current.messages[index].text += "\n\(error.localizedDescription)"
            current.messages[index].isStreaming = false
            model.updateThread(current)
        }

        isSending = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.text.isEmpty ? " " : message.text)
                    .font(message.role == .tool ? .system(.body, design: .monospaced) : .body)
                    .textSelection(.enabled)
                if message.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if message.role != .user { Spacer(minLength: 48) }
        }
    }

    private var label: String {
        switch message.role {
        case .user: "You"
        case .assistant: "GrokFS"
        case .tool: "Tool"
        case .system: "System"
        }
    }

    private var background: Color {
        switch message.role {
        case .user: Color.teal.opacity(0.18)
        case .assistant: Color.secondary.opacity(0.12)
        case .tool: Color.orange.opacity(0.12)
        case .system: Color.purple.opacity(0.12)
        }
    }
}
