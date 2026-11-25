import Foundation

public enum AccountType: String, Codable, Sendable, CaseIterable {
    case cash, bank, savings, creditCard = "credit_card", wallet

    /// Liability accounts show a negative balance as an amount owed (ADR-003).
    public var isLiability: Bool { self == .creditCard }

    public var displayName: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .wallet: "Wallet"
        }
    }

    public var systemImage: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .savings: "banknote.fill"
        case .creditCard: "creditcard"
        case .wallet: "wallet.bifold"
        }
    }
}

public struct Account: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var type: AccountType
    public var currency: CurrencyCode
    /// Signed opening balance. For credit cards an amount owed is negative.
    public var openingBalanceMinor: Int64
    public var sortOrder: Int
    public var archivedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: CurrencyCode = .inr,
        openingBalanceMinor: Int64 = 0,
        sortOrder: Int = 0,
        archivedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.openingBalanceMinor = openingBalanceMinor
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isArchived: Bool { archivedAt != nil }
    public var openingBalance: Money { Money(minorUnits: openingBalanceMinor, currency: currency) }
}
