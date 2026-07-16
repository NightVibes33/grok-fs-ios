import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

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
            }

            Section("Grok API") {
                TextField("Model", text: $settings.grokModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Endpoint", text: $settings.grokEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $settings.grokAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("FakeFS") {
                LabeledContent("Home", value: "/root")
                LabeledContent("Selected", value: model.selectedPath)
            }
        }
        .navigationTitle("Settings")
    }
}
