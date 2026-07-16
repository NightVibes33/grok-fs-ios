import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedThreadID) {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gear")
            }

            Section("Sessions") {
                ForEach(model.threads) { thread in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.title)
                            .font(.headline)
                        Text(thread.cwd)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(thread.id)
                }
            }
        }
        .navigationTitle("GrokFS")
        .toolbar {
            Button {
                model.newThread()
            } label: {
                Label("New Session", systemImage: "plus")
            }
        }
    }
}
