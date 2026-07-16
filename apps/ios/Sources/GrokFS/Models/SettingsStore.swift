import Foundation
import Observation

@Observable
final class SettingsStore {
    var grokEndpoint: String {
        didSet { UserDefaults.standard.set(grokEndpoint, forKey: "grokEndpoint") }
    }
    var grokModel: String {
        didSet { UserDefaults.standard.set(grokModel, forKey: "grokModel") }
    }
    var grokAPIKey: String {
        didSet { KeychainStore.write(grokAPIKey, account: "grokAPIKey") }
    }

    init() {
        self.grokEndpoint = UserDefaults.standard.string(forKey: "grokEndpoint") ?? "https://api.x.ai"
        self.grokModel = UserDefaults.standard.string(forKey: "grokModel") ?? "grok-4-latest"
        self.grokAPIKey = KeychainStore.read("grokAPIKey")
    }
}
