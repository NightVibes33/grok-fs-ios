import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            FileBrowserView()
        } detail: {
            ChatView()
        }
        .tint(.teal)
    }
}
