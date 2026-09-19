import Foundation
import OSLog
import Observation

@Observable
@MainActor
final class SettingsStore {
    var settings: AppSettings {
        didSet { persist() }
    }

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Settings")

    init() {
        if let data = try? Data(contentsOf: AppSettings.storageURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: AppSettings.storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resetToDefaults() {
        let onboarding = settings.hasCompletedOnboarding
        var defaults = AppSettings()
        defaults.hasCompletedOnboarding = onboarding
        settings = defaults
    }
}
