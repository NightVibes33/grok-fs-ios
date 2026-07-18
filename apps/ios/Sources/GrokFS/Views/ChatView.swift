import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @State private var composer = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider().opacity(0.45)
            composerDock
        }
        .background(GrokTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                runtimeHeader
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(RuntimeMode.allCases) { mode in
                        Button {
                            model.runtimeMode = mode
                        } label: {
                            if mode == model.runtimeMode {
                                Label(mode.rawValue, systemImage: "checkmark")
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(GrokTheme.textSecondary)
                }
            }
        }
    }

    private var runtimeHeader: some View {
        Menu {
            ForEach(RuntimeMode.allCases) { mode in
                Button(mode.rawValue) { model.runtimeMode = mode }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSending ? GrokTheme.warning : GrokTheme.success)
                    .frame(width: 7, height: 7)
                Text("GROK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(GrokTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(GrokTheme.accent.opacity(0.13), in: Capsule())
                Text(model.runtimeMode.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GrokTheme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(GrokTheme.textMuted)
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(model.selectedThread?.messages ?? []) { message in
                        TranscriptMessage(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.selectedThread?.messages.count ?? 0) {
                if let id = model.selectedThread?.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composerDock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Label("/root", systemImage: "folder.fill")
                Spacer()
                Text(model.runtimeMode.rawValue)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(GrokTheme.textMuted)
            .padding(.horizontal, 5)

            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button { composer = "$ " + composer } label: {
                        Label("Shell Command", systemImage: "terminal")
                    }
                    Button {
                        if !composer.isEmpty, !composer.hasSuffix(" ") { composer += " " }
                        composer += "/root/"
                    } label: {
                        Label("Workspace Path", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .foregroundStyle(GrokTheme.textSecondary)

                TextField("Ask Grok to build something", text: $composer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...7)
                    .padding(.vertical, 8)

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(GrokTheme.accent, in: Circle())
                }
                .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .opacity(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.1)))
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
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
            thread.title = String(prompt.prefix(38))
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
                    if index > 0, current.messages[index - 1].role == .tool {
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
                  let index = current.messages.firstIndex(where: { $0.id == assistant.id }) else {
                isSending = false
                return
            }
            current.messages[index].text += "\n\(error.localizedDescription)"
            current.messages[index].isStreaming = false
            model.updateThread(current)
        }
        isSending = false
    }
}

private struct TranscriptMessage: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 44)
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(GrokTheme.accent)
                        .frame(width: 22, height: 22)
                        .overlay(Text("G").font(.caption.bold()).foregroundStyle(.black))
                    Text("Grok")
                        .font(.subheadline.weight(.semibold))
                    if message.isStreaming {
                        ProgressView().controlSize(.mini)
                    }
                }
                Text(message.text.isEmpty ? " " : message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .tool:
            VStack(alignment: .leading, spacing: 7) {
                Label("Tool", systemImage: "terminal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GrokTheme.warning)
                Text(message.text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(GrokTheme.toolBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(GrokTheme.warning.opacity(0.2)))
        case .system:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(GrokTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
