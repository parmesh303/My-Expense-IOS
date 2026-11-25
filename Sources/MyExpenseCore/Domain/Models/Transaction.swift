import Foundation

public enum TransactionKind: String, Codable, Sendable, CaseIterable {
    case income, expense, refund, transfer

    /// Category kind required for this transaction kind; `nil` means no category (transfers).
    public var requiredCategoryKind: CategoryKind? {
        switch self {
        case .income: .income
        case .expense, .refund: .expense
        case .transfer: nil
        }
    }
}

public struct Transaction: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var kind: TransactionKind
    /// Always positive; direction comes from `kind` (FR-023).
    public var amount: Money
    public var occurredAt: Date
    public var occurredTimeZone: String
    /// Source account for transfers.
    public var accountId: UUID
    /// Destination account; only set for transfers.
    public var counterpartAccountId: UUID?
    public var categoryId: UUID?
    public var merchant: String?
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        kind: TransactionKind,
        amount: Money,
        occurredAt: Date = .now,
        occurredTimeZone: String = TimeZone.current.identifier,
        accountId: UUID,
        counterpartAccountId: UUID? = nil,
        categoryId: UUID? = nil,
        merchant: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.occurredTimeZone = occurredTimeZone
        self.accountId = accountId
        self.counterpartAccountId = counterpartAccountId
        self.categoryId = categoryId
        self.merchant = merchant
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }
}
