import Foundation
import MyExpenseCore
import Observation

/// Detail screen for one transaction (S6).
@MainActor
@Observable
public final class TransactionDetailViewModel {
    public private(set) var transaction: Transaction?
    public private(set) var row: TransactionPresenter.Row?
    public private(set) var categoryName = ""
    public private(set) var accountName = ""
    public private(set) var destinationName: String?
    public private(set) var errorMessage: String?

    public let transactionId: UUID
    private let container: AppContainer

    public init(container: AppContainer, transactionId: UUID) {
        self.container = container
        self.transactionId = transactionId
    }

    public func load() {
        do {
            let presenter = try TransactionPresenter(container: container)
            guard let transaction = try container.transactions.transaction(id: transactionId), !transaction.isDeleted else {
                self.transaction = nil
                return
            }
            self.transaction = transaction
            row = presenter.row(for: transaction)
            accountName = presenter.accountName(transaction.accountId)
            destinationName = transaction.counterpartAccountId.map { presenter.accountName($0) }
            categoryName = presenter.categoryName(transaction.categoryId)
        } catch {
            errorMessage = "This transaction could not be loaded."
        }
    }

    public func delete() -> Bool {
        do {
            try container.transactions.delete(id: transactionId)
            container.dataDidChange()
            return true
        } catch {
            errorMessage = "The transaction could not be deleted."
            return false
        }
    }
}
