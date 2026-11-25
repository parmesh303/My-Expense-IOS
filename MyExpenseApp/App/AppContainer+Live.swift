import Foundation
import MyExpenseFeatures
import SwiftData

extension AppContainer {
    /// Production container backed by on-device SwiftData storage.
    @MainActor
    static func live(inMemory: Bool = false) throws -> AppContainer {
        let modelContainer = try PersistenceFactory.makeContainer(inMemory: inMemory)
        let clock: @Sendable () -> Date = { .now }
        return AppContainer(
            profiles: SwiftDataProfileRepository(container: modelContainer),
            accounts: SwiftDataAccountRepository(container: modelContainer, clock: clock),
            categories: SwiftDataCategoryRepository(container: modelContainer, clock: clock),
            transactions: SwiftDataTransactionRepository(container: modelContainer, clock: clock),
            receipts: SwiftDataReceiptRepository(container: modelContainer),
            receiptFiles: FileReceiptStore(directory: try FileReceiptStore.defaultDirectory()),
            clock: clock
        )
    }
}
