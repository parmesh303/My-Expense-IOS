import Foundation
import MyExpenseCore
import Observation

/// Drives the first-run flow (FR-001, FR-002, FR-004, FR-005, FR-006).
@MainActor
@Observable
public final class OnboardingViewModel {
    public enum Step: Int, CaseIterable, Sendable {
        case welcome, storage, preferences, firstAccount
    }

    public static let supportedCurrencies = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "AUD", "CAD", "JPY"]
        .compactMap(CurrencyCode.init(rawValue:))

    public var step: Step = .welcome
    public var storageMode: StorageMode = .localOnly
    /// The user must acknowledge that on-device data is not a backup (FR-005).
    public var acknowledgedLocalOnlyRisk = false
    public var displayName = ""
    public var currency: CurrencyCode = .inr
    public var firstWeekday = 2
    public var createFirstAccount = true
    public var accountName = "Cash"
    public var accountType: AccountType = .cash
    /// For credit cards this is the amount currently owed.
    public var openingBalanceText = "0"
    public private(set) var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var canContinue: Bool {
        switch step {
        case .welcome: true
        case .storage: storageMode == .localOnly && acknowledgedLocalOnlyRisk
        case .preferences: (try? draftProfile.validate()) != nil
        case .firstAccount: !createFirstAccount || (accountNameIsValid && (try? openingBalanceMinor()) != nil)
        }
    }

    public var isLastStep: Bool { step == Step.allCases.last }

    public func next() {
        guard canContinue, let next = Step(rawValue: step.rawValue + 1) else { return }
        errorMessage = nil
        step = next
    }

    public func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        errorMessage = nil
        step = previous
    }

    /// Persists categories, the optional first account and the profile.
    /// The profile is saved last, so an interrupted onboarding restarts cleanly.
    @discardableResult
    public func finish() -> Bool {
        errorMessage = nil
        do {
            var profile = draftProfile
            try profile.validate()
            profile.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            try container.categories.seedDefaultsIfNeeded()
            if createFirstAccount {
                guard accountNameIsValid else { throw OnboardingError.invalidAccountName }
                let now = container.clock()
                try container.accounts.save(Account(
                    name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: accountType,
                    currency: currency,
                    openingBalanceMinor: try openingBalanceMinor(),
                    createdAt: now,
                    updatedAt: now
                ))
            }
            try container.updateProfile(profile)
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private var draftProfile: Profile {
        let now = container.clock()
        return Profile(
            displayName: displayName,
            preferredCurrency: currency,
            firstWeekday: firstWeekday,
            storageMode: storageMode,
            createdAt: now,
            updatedAt: now
        )
    }

    private var accountNameIsValid: Bool {
        let trimmed = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 60
    }

    private func openingBalanceMinor() throws -> Int64 {
        let text = openingBalanceText.trimmingCharacters(in: .whitespaces)
        let money = try Money(parsing: text.isEmpty ? "0" : text, currency: currency)
        guard money.minorUnits >= 0 else { throw OnboardingError.negativeOpeningBalance }
        // Credit card debt is stored as a negative balance (ADR-003).
        return accountType.isLiability ? -money.minorUnits : money.minorUnits
    }

    private enum OnboardingError: Error {
        case invalidAccountName, negativeOpeningBalance
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case Profile.ValidationError.emptyName: "Please enter your name."
        case Profile.ValidationError.nameTooLong: "Name must be \(Profile.maxNameLength) characters or fewer."
        case OnboardingError.invalidAccountName: "Please enter an account name."
        case OnboardingError.negativeOpeningBalance, MoneyError.invalidNumber: "Enter a valid opening balance."
        default: "Something went wrong while saving. Please try again."
        }
    }
}
