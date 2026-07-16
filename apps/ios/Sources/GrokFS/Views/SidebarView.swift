import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var renamingThreadID: UUID?
    @State private var renameText = ""

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
                            .lineLimit(2)
                        HStack {
                            Text(thread.cwd)
                            Spacer()
                            Text(thread.updatedAt, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .tag(thread.id)
                    .contextMenu {
                        Button {
                            renamingThreadID = thread.id
                            renameText = thread.title
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            model.deleteThread(id: thread.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            model.deleteThread(id: thread.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
        .alert("Rename Session", isPresented: Binding(
            get: { renamingThreadID != nil },
            set: { if !$0 { renamingThreadID = nil } }
        )) {
            TextField("Session name", text: $renameText)
            Button("Rename") {
                if let id = renamingThreadID {
                    model.renameThread(id: id, title: renameText)
                }
                renamingThreadID = nil
            }
            Button("Cancel", role: .cancel) {
                renamingThreadID = nil
            }
        }
    }
}
