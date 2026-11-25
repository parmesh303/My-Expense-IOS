import Foundation

/// Which kind of transaction a category may be assigned to (FR-053).
public enum CategoryKind: String, Codable, Sendable, CaseIterable {
    case income, expense
}

public struct TransactionCategory: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: CategoryKind
    /// SF Symbol name.
    public var icon: String
    public var colorHex: String?
    public var isSystem: Bool
    public var sortOrder: Int
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: CategoryKind,
        icon: String,
        colorHex: String? = nil,
        isSystem: Bool = false,
        sortOrder: Int = 0,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.icon = icon
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }
}

public enum DefaultCategories {
    /// SRS §6.5 suggested defaults. "Refund" is a transaction kind (ADR-004), not an income category.
    public static func make() -> [TransactionCategory] {
        let expense: [(String, String, String)] = [
            ("Food", "fork.knife", "#F97316"),
            ("Groceries", "cart", "#22C55E"),
            ("Shopping", "bag", "#EC4899"),
            ("Travel", "airplane", "#0EA5E9"),
            ("Rent", "house", "#8B5CF6"),
            ("Utilities", "bolt", "#EAB308"),
            ("Healthcare", "cross.case", "#EF4444"),
            ("Entertainment", "film", "#A855F7"),
            ("Education", "book", "#3B82F6"),
            ("EMI/Loans", "indianrupeesign.circle", "#64748B"),
            ("Personal Care", "sparkles", "#14B8A6"),
            ("Other", "ellipsis.circle", "#94A3B8"),
        ]
        let income: [(String, String, String)] = [
            ("Salary", "briefcase", "#16A34A"),
            ("Freelance", "laptopcomputer", "#0D9488"),
            ("Business", "storefront", "#2563EB"),
            ("Interest", "percent", "#7C3AED"),
            ("Gift", "gift", "#DB2777"),
            ("Other Income", "plus.circle", "#94A3B8"),
        ]
        let expenseCategories = expense.enumerated().map { index, item in
            TransactionCategory(name: item.0, kind: .expense, icon: item.1, colorHex: item.2, isSystem: true, sortOrder: index)
        }
        let incomeCategories = income.enumerated().map { index, item in
            TransactionCategory(name: item.0, kind: .income, icon: item.1, colorHex: item.2, isSystem: true, sortOrder: index)
        }
        return expenseCategories + incomeCategories
    }
}
