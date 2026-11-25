import Foundation
import MyExpenseCore
import Observation

/// Dependency container shared through the SwiftUI environment.
/// The app builds it with SwiftData repositories; tests and previews use in-memory ones.
@MainActor
@Observable
public final class AppContainer {
    public let profiles: any ProfileRepository
    public let accounts: any AccountRepository
    public let categories: any CategoryRepository
    public let transactions: any TransactionRepository
    public let receipts: any ReceiptRepository
    public let receiptFiles: any ReceiptFileStore
    @ObservationIgnored public let clock: @Sendable () -> Date

    /// `nil` until onboarding completes.
    public private(set) var profile: Profile?
    /// Incremented after any data change so screens can reload (`.task(id:)`).
    public private(set) var dataVersion = 0
    public private(set) var startupError: String?

    public init(
        profiles: any ProfileRepository,
        accounts: any AccountRepository,
        categories: any CategoryRepository,
        transactions: any TransactionRepository,
        receipts: any ReceiptRepository,
        receiptFiles: any ReceiptFileStore,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.profiles = profiles
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.receipts = receipts
        self.receiptFiles = receiptFiles
        self.clock = clock
        do {
            profile = try profiles.current()
        } catch {
            startupError = "Your data could not be loaded. Please restart the app."
        }
    }

    /// Calendar in the device time zone using the user's first day of week.
    public var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .current
        if let firstWeekday = profile?.firstWeekday { calendar.firstWeekday = firstWeekday }
        return calendar
    }

    public var currency: CurrencyCode { profile?.preferredCurrency ?? .inr }

    public func updateProfile(_ profile: Profile) throws {
        try profiles.save(profile)
        self.profile = profile
        dataDidChange()
    }

    public func dataDidChange() {
        dataVersion &+= 1
    }

    /// Validator built from current accounts and categories, including archived ones.
    public func makeValidator() throws -> TransactionValidator {
        TransactionValidator(
            accounts: try accounts.all(includeArchived: true),
            categories: try categories.all(includeArchived: true)
        )
    }

    /// Empty in-memory container for tests and SwiftUI previews.
    public static func inMemory(profile: Profile? = nil, clock: @escaping @Sendable () -> Date = { .now }) -> AppContainer {
        AppContainer(
            profiles: InMemoryProfileRepository(profile: profile),
            accounts: InMemoryAccountRepository(clock: clock),
            categories: InMemoryCategoryRepository(clock: clock),
            transactions: InMemoryTransactionRepository(clock: clock),
            receipts: InMemoryReceiptRepository(),
            receiptFiles: FileReceiptStore(directory: FileManager.default.temporaryDirectory
                .appending(path: "MyExpensePreviewReceipts-\(UUID().uuidString)", directoryHint: .isDirectory)),
            clock: clock
        )
    }
}
