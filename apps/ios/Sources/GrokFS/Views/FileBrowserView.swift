import SwiftUI

struct FileBrowserView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedFile: WorkspaceItem?
    @State private var editorText = ""
    @State private var showingNewFile = false
    @State private var newFileName = ""

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            pathBar
            List(model.workspace.list(model.selectedPath), selection: $selectedFile) { item in
                Button {
                    open(item)
                } label: {
                    Label(item.name, systemImage: item.isDirectory ? "folder" : "doc.text")
                }
            }
            if selectedFile?.isDirectory == false {
                Divider()
                TextEditor(text: $editorText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                Button {
                    saveSelectedFile()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle("Files")
        .toolbar {
            Button {
                showingNewFile = true
            } label: {
                Label("New File", systemImage: "doc.badge.plus")
            }
        }
        .alert("New File", isPresented: $showingNewFile) {
            TextField("name.txt", text: $newFileName)
            Button("Create") { createFile() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var pathBar: some View {
        HStack {
            Button {
                model.selectedPath = parent(of: model.selectedPath)
                selectedFile = nil
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(model.selectedPath == "/")

            Text(model.selectedPath)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial)
    }

    private func open(_ item: WorkspaceItem) {
        selectedFile = item
        if item.isDirectory {
            model.selectedPath = item.path
            editorText = ""
        } else {
            editorText = (try? model.workspace.readText(item.path)) ?? ""
        }
    }

    private func saveSelectedFile() {
        guard let selectedFile, !selectedFile.isDirectory else { return }
        try? model.workspace.writeText(editorText, to: selectedFile.path)
    }

    private func createFile() {
        let trimmed = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let path = "\(model.selectedPath == "/" ? "" : model.selectedPath)/\(trimmed)"
        try? model.workspace.writeText("", to: path)
        newFileName = ""
    }

    private func parent(of path: String) -> String {
        let parts = path.split(separator: "/").dropLast()
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }
}
