import Foundation
import MyExpenseCore
import Observation

/// Edits profile preferences from the Settings tab (FR-110).
@MainActor
@Observable
public final class SettingsViewModel {
    public var displayName: String
    public var currency: CurrencyCode
    public var firstWeekday: Int
    public private(set) var errorMessage: String?
    public private(set) var didSave = false

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
        displayName = container.profile?.displayName ?? ""
        currency = container.profile?.preferredCurrency ?? .inr
        firstWeekday = container.profile?.firstWeekday ?? 2
    }

    public var storageDescription: String {
        switch container.profile?.storageMode ?? .localOnly {
        case .localOnly:
            "Your data is stored only on this iPhone. It is not backed up. If you lose or reset this device, your records cannot be recovered unless you have exported them."
        case .cloud:
            "Your data is stored on this iPhone and synced to your cloud account."
        }
    }

    public var hasChanges: Bool {
        guard let profile = container.profile else { return false }
        return profile.displayName != displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            || profile.preferredCurrency != currency
            || profile.firstWeekday != firstWeekday
    }

    public func save() {
        guard var profile = container.profile else { return }
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.preferredCurrency = currency
        profile.firstWeekday = firstWeekday
        profile.updatedAt = container.clock()
        do {
            try profile.validate()
            try container.updateProfile(profile)
            errorMessage = nil
            didSave = true
        } catch Profile.ValidationError.emptyName {
            errorMessage = "Please enter your name."
        } catch Profile.ValidationError.nameTooLong {
            errorMessage = "Name must be \(Profile.maxNameLength) characters or fewer."
        } catch {
            errorMessage = "Settings could not be saved. Please try again."
        }
    }
}
