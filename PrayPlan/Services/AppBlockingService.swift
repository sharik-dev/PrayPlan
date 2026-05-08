import Foundation
import FamilyControls
import ManagedSettings
import Observation

@Observable
@MainActor
final class AppBlockingService {
    private(set) var isAuthorized = false
    private(set) var authorizationError: String?

    private let store = ManagedSettingsStore()

    init() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func checkStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
        }
    }

    func applyBlocking(profile: AppBlockingProfile?) {
        guard let profile, profile.isEnabled,
              let data = profile.selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    func clearBlocking() {
        store.clearAllSettings()
    }
}
