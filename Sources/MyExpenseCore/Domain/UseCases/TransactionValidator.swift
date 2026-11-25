import Foundation

public enum TransactionValidationError: Error, Equatable, Sendable {
    case nonPositiveAmount
    case unknownAccount
    case archivedAccount
    case currencyMismatch
    case missingCategory
    case unknownCategory
    case incompatibleCategory
    case archivedCategory
    case missingDestinationAccount
    case sameAccountTransfer
    case transferHasCategory
    case unexpectedDestinationAccount
    case textTooLong
}

/// Validates a transaction against the SRS rules before it is saved.
public struct TransactionValidator: Sendable {
    public static let maxTextLength = 500

    public let accounts: [UUID: Account]
    public let categories: [UUID: TransactionCategory]

    public init(accounts: [Account], categories: [TransactionCategory]) {
        self.accounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.categories = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    /// Validates a new or edited transaction.
    /// - Parameter original: The stored version when editing. Archived accounts and categories it
    ///   already references stay valid, so historical records can still be corrected (FR-054).
    public func validate(_ transaction: Transaction, original: Transaction? = nil) throws(TransactionValidationError) {
        guard transaction.amount.isPositive else { throw .nonPositiveAmount }
        if (transaction.notes?.count ?? 0) > Self.maxTextLength || (transaction.merchant?.count ?? 0) > Self.maxTextLength {
            throw .textTooLong
        }

        let previousAccounts: Set<UUID> = [original?.accountId, original?.counterpartAccountId].reduce(into: []) {
            if let id = $1 { $0.insert(id) }
        }
        let source = try account(transaction.accountId, allowArchived: previousAccounts)
        guard source.currency == transaction.amount.currency else { throw .currencyMismatch }

        if transaction.kind == .transfer {
            guard transaction.categoryId == nil else { throw .transferHasCategory }
            guard let destinationId = transaction.counterpartAccountId else { throw .missingDestinationAccount }
            guard destinationId != transaction.accountId else { throw .sameAccountTransfer }
            let destination = try account(destinationId, allowArchived: previousAccounts)
            // Multi-currency transfers are out of MVP scope (ADR-001).
            guard destination.currency == source.currency else { throw .currencyMismatch }
            return
        }

        guard transaction.counterpartAccountId == nil else { throw .unexpectedDestinationAccount }
        guard let categoryId = transaction.categoryId else { throw .missingCategory }
        guard let category = categories[categoryId] else { throw .unknownCategory }
        guard category.kind == transaction.kind.requiredCategoryKind else { throw .incompatibleCategory }
        if category.isArchived && original?.categoryId != categoryId { throw .archivedCategory }
    }

    private func account(_ id: UUID, allowArchived: Set<UUID>) throws(TransactionValidationError) -> Account {
        guard let account = accounts[id] else { throw .unknownAccount }
        if account.isArchived && !allowArchived.contains(id) { throw .archivedAccount }
        return account
    }
}
