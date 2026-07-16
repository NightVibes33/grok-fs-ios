import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var runtimeStatus = "Not checked"
    @State private var isCheckingRuntime = false

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var model = model

        Form {
            Section("Runtime") {
                Picker("Agent", selection: $model.runtimeMode) {
                    ForEach(RuntimeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                LabeledContent("Status", value: runtimeStatus)
                Button {
                    Task { await verifyRuntime() }
                } label: {
                    Label("Verify Runtime", systemImage: "checkmark.shield")
                }
                .disabled(isCheckingRuntime)
            }

            Section("xAI Authentication") {
                SecureField("API Key", text: $settings.grokAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text(settings.grokAPIKey.isEmpty ? "Required for Grok Build and API modes." : "Stored in Keychain on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.runtimeMode == .grokAPI {
                Section("Direct API Fallback") {
                    TextField("Model", text: $settings.grokModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Endpoint", text: $settings.grokEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Section("Workspace") {
                LabeledContent("Filesystem", value: "Embedded iSH")
                LabeledContent("Home", value: "/root")
                LabeledContent("Selected", value: model.selectedPath)
                LabeledContent("Grok sessions", value: "/root/.grok")
            }

            Section("Source") {
                LabeledContent("Grok Build", value: "b189869")
                LabeledContent("litter-ish", value: "c8e9dcb")
                LabeledContent("License", value: "GPL-3.0-or-later")
            }
        }
        .navigationTitle("Settings")
    }

    @MainActor
    private func verifyRuntime() async {
        isCheckingRuntime = true
        defer { isCheckingRuntime = false }
        do {
            let result = try await EmbeddedIshRuntime.shared.run(
                "printf 'iSH '; uname -m; /usr/local/bin/grok --version",
                cwd: "/root",
                timeout: .seconds(30)
            )
            runtimeStatus = result.exitCode == 0
                ? result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Unavailable: \(result.output)"
        } catch {
            runtimeStatus = error.localizedDescription
        }
    }
}
