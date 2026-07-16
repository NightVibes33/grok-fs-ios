import SwiftUI

struct FileBrowserView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [WorkspaceItem] = []
    @State private var selectedFile: WorkspaceItem?
    @State private var editorText = ""
    @State private var showingNewFile = false
    @State private var showingNewFolder = false
    @State private var newFileName = ""
    @State private var newFolderName = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var hasLoadedWorkspace = false

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            List(items, selection: $selectedFile) { item in
                Button {
                    Task { await open(item) }
                } label: {
                    Label(item.name, systemImage: item.isDirectory ? "folder" : "doc.text")
                }
            }
            .overlay {
                if isWorking { ProgressView() }
            }

            if selectedFile?.isDirectory == false {
                Divider()
                TextEditor(text: $editorText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                Button {
                    Task { await saveSelectedFile() }
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
            Menu {
                Button { showingNewFile = true } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                Button { showingNewFolder = true } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button(role: .destructive) {
                    Task { await deleteSelectedItem() }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedFile == nil)
            } label: {
                Label("File Actions", systemImage: "plus")
            }
            Button {
                Task { await reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .onChange(of: model.selectedPath) {
            guard hasLoadedWorkspace else { return }
            Task { await reload() }
        }
        .alert("New File", isPresented: $showingNewFile) {
            TextField("name.txt", text: $newFileName)
            Button("Create") { Task { await createFile() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("folder", text: $newFolderName)
            Button("Create") { Task { await createFolder() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Filesystem Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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

    @MainActor
    private func reload() async {
        hasLoadedWorkspace = true
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await EmbeddedIshRuntime.shared.run(
                "ls -A1p -- \(shellQuote(model.selectedPath))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else {
                throw FilesystemError.command(result.output)
            }
            items = result.output
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .map { raw in
                    let isDirectory = raw.hasSuffix("/")
                    let name = isDirectory ? String(raw.dropLast()) : raw
                    let base = model.selectedPath == "/" ? "" : model.selectedPath
                    return WorkspaceItem(
                        path: "\(base)/\(name)",
                        name: name,
                        isDirectory: isDirectory,
                        size: 0,
                        modifiedAt: nil
                    )
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func open(_ item: WorkspaceItem) async {
        selectedFile = item
        if item.isDirectory {
            model.selectedPath = item.path
            editorText = ""
            return
        }
        do {
            let result = try await EmbeddedIshRuntime.shared.run(
                "cat -- \(shellQuote(item.path))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else { throw FilesystemError.command(result.output) }
            editorText = result.output
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveSelectedFile() async {
        guard let selectedFile, !selectedFile.isDirectory else { return }
        do {
            let encoded = Data(editorText.utf8).base64EncodedString()
            let result = try await EmbeddedIshRuntime.shared.run(
                "printf %s \(shellQuote(encoded)) | base64 -d > \(shellQuote(selectedFile.path))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else { throw FilesystemError.command(result.output) }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createFile() async {
        let trimmed = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return }
        let path = "\(model.selectedPath == "/" ? "" : model.selectedPath)/\(trimmed)"
        do {
            let result = try await EmbeddedIshRuntime.shared.run(
                ": > \(shellQuote(path))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else { throw FilesystemError.command(result.output) }
            newFileName = ""
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createFolder() async {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return }
        let path = "\(model.selectedPath == "/" ? "" : model.selectedPath)/\(trimmed)"
        do {
            let result = try await EmbeddedIshRuntime.shared.run(
                "mkdir -- \(shellQuote(path))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else { throw FilesystemError.command(result.output) }
            newFolderName = ""
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteSelectedItem() async {
        guard let selectedFile else { return }
        do {
            let command = selectedFile.isDirectory ? "rm -rf --" : "rm -f --"
            let result = try await EmbeddedIshRuntime.shared.run(
                "\(command) \(shellQuote(selectedFile.path))",
                cwd: model.selectedPath,
                timeout: .seconds(30)
            )
            guard result.exitCode == 0 else { throw FilesystemError.command(result.output) }
            self.selectedFile = nil
            editorText = ""
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func parent(of path: String) -> String {
        let parts = path.split(separator: "/").dropLast()
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }
}

private enum FilesystemError: LocalizedError {
    case command(String)

    var errorDescription: String? {
        switch self {
        case let .command(output): output.isEmpty ? "The filesystem command failed." : output
        }
    }
}
