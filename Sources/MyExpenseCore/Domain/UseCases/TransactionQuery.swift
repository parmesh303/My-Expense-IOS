import Foundation

public enum TransactionSort: String, Codable, Sendable, CaseIterable {
    case dateDescending, dateAscending, amountDescending, amountAscending
}

/// Search, filter and sort criteria for the transaction list (FR-026, FR-027, FR-028).
public struct TransactionQuery: Hashable, Sendable {
    public var searchText: String = ""
    public var dateRange: ReportingPeriod?
    public var kinds: Set<TransactionKind> = []
    /// Matches either side of a transfer.
    public var accountIds: Set<UUID> = []
    public var categoryIds: Set<UUID> = []
    public var minAmountMinor: Int64?
    public var maxAmountMinor: Int64?
    public var sort: TransactionSort = .dateDescending
    public var includeDeleted = false

    public init() {}

    public func matches(_ transaction: Transaction, categoryNames: [UUID: String] = [:], accountNames: [UUID: String] = [:]) -> Bool {
        if !includeDeleted && transaction.isDeleted { return false }
        if let dateRange, !dateRange.contains(transaction.occurredAt) { return false }
        if !kinds.isEmpty && !kinds.contains(transaction.kind) { return false }
        if !accountIds.isEmpty {
            let touched = [transaction.accountId, transaction.counterpartAccountId].compactMap { $0 }
            if !touched.contains(where: accountIds.contains) { return false }
        }
        if !categoryIds.isEmpty {
            guard let categoryId = transaction.categoryId, categoryIds.contains(categoryId) else { return false }
        }
        if let minAmountMinor, transaction.amount.minorUnits < minAmountMinor { return false }
        if let maxAmountMinor, transaction.amount.minorUnits > maxAmountMinor { return false }

        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystack: [String?] = [
            transaction.merchant,
            transaction.notes,
            transaction.categoryId.flatMap { categoryNames[$0] },
            accountNames[transaction.accountId],
            transaction.counterpartAccountId.flatMap { accountNames[$0] },
            "\(transaction.amount.decimalValue)",
        ]
        return haystack.contains { $0?.localizedStandardContains(needle) ?? false }
    }

    /// Stable ordering; ties are broken by date then id so paging never skips or repeats rows.
    public func areInIncreasingOrder(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        switch sort {
        case .dateDescending:
            if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        case .dateAscending:
            if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
        case .amountDescending:
            if lhs.amount.minorUnits != rhs.amount.minorUnits { return lhs.amount.minorUnits > rhs.amount.minorUnits }
            if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        case .amountAscending:
            if lhs.amount.minorUnits != rhs.amount.minorUnits { return lhs.amount.minorUnits < rhs.amount.minorUnits }
            if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

/// Offset-based page for incremental loading (FR-032).
public struct PageRequest: Hashable, Sendable {
    public var offset: Int
    public var limit: Int

    public init(offset: Int = 0, limit: Int = 50) {
        precondition(offset >= 0 && limit > 0)
        self.offset = offset
        self.limit = limit
    }

    public var next: PageRequest { PageRequest(offset: offset + limit, limit: limit) }
}
