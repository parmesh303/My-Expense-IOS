import Foundation
import MyExpenseCore

/// Display text and icons for transactions, shared by the list, dashboard and detail screens.
public struct TransactionPresenter: Sendable {
    public struct Row: Identifiable, Hashable, Sendable {
        public let transaction: Transaction
        public let title: String
        public let subtitle: String
        public let icon: String
        public let colorHex: String?
        public var id: UUID { transaction.id }
    }

    public let accounts: [UUID: Account]
    public let categories: [UUID: TransactionCategory]

    public init(accounts: [Account], categories: [TransactionCategory]) {
        self.accounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.categories = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    @MainActor
    public init(container: AppContainer) throws {
        self.init(accounts: try container.accounts.all(includeArchived: true), categories: try container.categories.all(includeArchived: true))
    }

    public var categoryNames: [UUID: String] { categories.mapValues(\.name) }
    public var accountNames: [UUID: String] { accounts.mapValues(\.name) }

    public func accountName(_ id: UUID?) -> String {
        id.flatMap { accounts[$0]?.name } ?? "Unknown account"
    }

    /// Archived categories keep their name with a marker so history stays readable (FR-054).
    public func categoryName(_ id: UUID?) -> String {
        guard let category = id.flatMap({ categories[$0] }) else { return "Uncategorized" }
        return category.isArchived ? "\(category.name) (archived)" : category.name
    }

    public func row(for transaction: Transaction) -> Row {
        let account = accountName(transaction.accountId)
        if transaction.kind == .transfer {
            return Row(
                transaction: transaction,
                title: "Transfer",
                subtitle: "\(account) → \(accountName(transaction.counterpartAccountId))",
                icon: "arrow.left.arrow.right",
                colorHex: nil
            )
        }
        let category = transaction.categoryId.flatMap { categories[$0] }
        let categoryLabel = categoryName(transaction.categoryId)
        let merchant = transaction.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (merchant?.isEmpty == false ? merchant : nil) ?? category?.name ?? "Uncategorized"
        let prefix = transaction.kind == .refund ? "Refund · " : ""
        return Row(
            transaction: transaction,
            title: title,
            subtitle: "\(prefix)\(categoryLabel) · \(account)",
            icon: category?.icon ?? "questionmark.circle",
            colorHex: category?.colorHex
        )
    }
}
