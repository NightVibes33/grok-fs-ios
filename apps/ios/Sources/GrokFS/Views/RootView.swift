import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab: AppTab = .chat

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ChatView()
            }
            .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            .tag(AppTab.chat)

            NavigationStack {
                FileBrowserView()
            }
            .tabItem { Label("Files", systemImage: "folder") }
            .tag(AppTab.files)

            NavigationStack {
                SidebarView()
            }
            .tabItem { Label("Sessions", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.sessions)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(AppTab.settings)
        }
        .tint(.teal)
        .onChange(of: model.selectedThreadID) {
            if selectedTab == .sessions { selectedTab = .chat }
        }
    }
}

private enum AppTab: Hashable {
    case chat
    case files
    case sessions
    case settings
}
