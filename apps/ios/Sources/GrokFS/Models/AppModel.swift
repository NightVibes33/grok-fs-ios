import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let workspace: WorkspaceStore
    let shell: FakeFSShell
    let settings: SettingsStore
    var threads: [ChatThread]
    var selectedThreadID: UUID?
    var selectedPath: String = "/root"
    var runtimeMode: RuntimeMode = .localShell

    init() {
        let workspace = WorkspaceStore()
        self.workspace = workspace
        self.shell = FakeFSShell(workspace: workspace)
        self.settings = SettingsStore()
        self.threads = ChatThreadStore.load()
        if threads.isEmpty {
            let initial = ChatThread(title: "Workspace", messages: [
                ChatMessage(role: .assistant, text: "GrokFS is ready. Prefix a message with `$` to run it in /root, or ask for workspace help.")
            ])
            self.threads = [initial]
            ChatThreadStore.save([initial])
        }
        self.selectedThreadID = threads.first?.id
        workspace.bootstrap()
    }

    var activeRuntime: any AgentRuntime {
        switch runtimeMode {
        case .localShell:
            LocalShellAgentRuntime(shell: shell)
        case .grokAPI:
            GrokAPIRuntime(endpoint: URL(string: settings.grokEndpoint), apiKey: settings.grokAPIKey, model: settings.grokModel)
        }
    }

    var selectedThread: ChatThread? {
        get {
            guard let selectedThreadID else { return threads.first }
            return threads.first { $0.id == selectedThreadID }
        }
        set {
            guard let newValue, let index = threads.firstIndex(where: { $0.id == newValue.id }) else { return }
            threads[index] = newValue
            ChatThreadStore.save(threads)
        }
    }

    func newThread() {
        let thread = ChatThread(title: "New Session", messages: [])
        threads.insert(thread, at: 0)
        selectedThreadID = thread.id
        ChatThreadStore.save(threads)
    }

    func updateThread(_ thread: ChatThread) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        threads[index] = thread
        ChatThreadStore.save(threads)
    }
}

enum RuntimeMode: String, CaseIterable, Identifiable, Codable {
    case localShell = "Local Shell"
    case grokAPI = "Grok API"

    var id: String { rawValue }
}
