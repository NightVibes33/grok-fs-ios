import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [WorkspaceRoute] = []
    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        NavigationStack(path: $path) {
            dashboard
                .navigationDestination(for: WorkspaceRoute.self) { route in
                    switch route {
                    case .chat:
                        ChatView()
                    case .files:
                        FileBrowserView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .tint(GrokTheme.accent)
    }

    private var dashboard: some View {
        ZStack {
            GrokTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                contextBar
                sessionList
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { path.append(.settings) } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(GrokTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .principal) {
                GrokMark()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { path.append(.files) } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(GrokTheme.textSecondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var contextBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(GrokTheme.success)
                .frame(width: 7, height: 7)
            Text("ON DEVICE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(GrokTheme.accent)
            Text("iSH")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Label("/root", systemImage: "folder.fill")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(GrokTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    private var filteredThreads: [ChatThread] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.threads }
        return model.threads.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.messages.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if filteredThreads.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a Grok workspace session.")
                    )
                    .padding(.top, 90)
                } else {
                    ForEach(filteredThreads) { thread in
                        Button {
                            model.selectedThreadID = thread.id
                            path.append(.chat)
                        } label: {
                            sessionRow(thread)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.deleteThread(id: thread.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sessionRow(_ thread: ChatThread) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(thread.messages.last?.isStreaming == true ? GrokTheme.warning : GrokTheme.success)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(thread.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GrokTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(thread.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(GrokTheme.textMuted)
                }
                Text(thread.messages.last?.text ?? "New Grok session")
                    .font(.system(size: 13))
                    .foregroundStyle(GrokTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 7) {
                    Text("GROK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(GrokTheme.accent)
                    Text(thread.cwd)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GrokTheme.textMuted)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GrokTheme.textMuted)
                .padding(.top, 5)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(GrokTheme.rowBackground)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(GrokTheme.accent)
                    TextField("Search sessions", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                    Button {
                        searchText = ""
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                            isSearching = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(.regularMaterial, in: Capsule())
            } else {
                Spacer()
                Button {
                    model.newThread()
                    path.append(.chat)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 46, height: 46)
                }
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(GrokTheme.accent.opacity(0.45)))
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        isSearching = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 46, height: 46)
                }
                .foregroundStyle(GrokTheme.textSecondary)
                .background(.regularMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private enum WorkspaceRoute: Hashable {
    case chat
    case files
    case settings
}

struct GrokMark: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(GrokTheme.accent)
                    .frame(width: 30, height: 30)
                Text("G")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.black)
            }
            Text("GrokFS")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(GrokTheme.textPrimary)
        }
    }
}

enum GrokTheme {
    static let accent = Color(red: 0.34, green: 0.93, blue: 0.78)
    static let success = Color(red: 0.27, green: 0.84, blue: 0.52)
    static let warning = Color(red: 1.0, green: 0.69, blue: 0.25)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textMuted = Color.secondary.opacity(0.62)
    static let rowBackground = Color.primary.opacity(0.035)
    static let toolBackground = Color.orange.opacity(0.09)
    static let background = Color(uiColor: .systemBackground)
}
