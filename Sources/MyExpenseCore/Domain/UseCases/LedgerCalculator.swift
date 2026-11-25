import Foundation

public struct PeriodSummary: Hashable, Sendable {
    public var income: Money
    public var expenses: Money
    public var refunds: Money

    /// Expenses minus refunds (ADR-004).
    public var netSpending: Money { Money(minorUnits: expenses.minorUnits - refunds.minorUnits, currency: expenses.currency) }
    /// Income minus net spending. Transfers never contribute (FR-016, FR-087).
    public var netCashFlow: Money { Money(minorUnits: income.minorUnits - netSpending.minorUnits, currency: income.currency) }
}

public struct CategoryTotal: Hashable, Sendable {
    public var categoryId: UUID?
    public var amount: Money
}

/// Single source of truth for balances and totals. Balances are derived from
/// opening balance + ledger rows, never stored (ADR-005, FR-047).
public enum LedgerCalculator {
    /// Signed effect of a transaction on one account, in that account's currency's minor units.
    public static func effect(of transaction: Transaction, on accountId: UUID) -> Int64 {
        guard !transaction.isDeleted else { return 0 }
        let amount = transaction.amount.minorUnits
        switch transaction.kind {
        case .income, .refund:
            return transaction.accountId == accountId ? amount : 0
        case .expense:
            return transaction.accountId == accountId ? -amount : 0
        case .transfer:
            var delta: Int64 = 0
            if transaction.accountId == accountId { delta -= amount }
            if transaction.counterpartAccountId == accountId { delta += amount }
            return delta
        }
    }

    /// Balance of `account` including all non-deleted transactions up to and including `asOf`.
    public static func balance(of account: Account, transactions: some Sequence<Transaction>, asOf: Date? = nil) -> Money {
        var total = account.openingBalanceMinor
        for transaction in transactions where asOf.map({ transaction.occurredAt <= $0 }) ?? true {
            total += effect(of: transaction, on: account.id)
        }
        return Money(minorUnits: total, currency: account.currency)
    }

    public static func balances(of accounts: [Account], transactions: [Transaction]) -> [UUID: Money] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, balance(of: $0, transactions: transactions)) })
    }

    /// Income/expense/refund totals for one currency within `period`, optionally limited to some accounts.
    public static func summary(
        of transactions: some Sequence<Transaction>,
        in period: ReportingPeriod,
        currency: CurrencyCode,
        accountIds: Set<UUID>? = nil
    ) -> PeriodSummary {
        var income: Int64 = 0, expenses: Int64 = 0, refunds: Int64 = 0
        for transaction in transactions where qualifies(transaction, period: period, currency: currency, accountIds: accountIds) {
            switch transaction.kind {
            case .income: income += transaction.amount.minorUnits
            case .expense: expenses += transaction.amount.minorUnits
            case .refund: refunds += transaction.amount.minorUnits
            case .transfer: break
            }
        }
        return PeriodSummary(
            income: Money(minorUnits: income, currency: currency),
            expenses: Money(minorUnits: expenses, currency: currency),
            refunds: Money(minorUnits: refunds, currency: currency)
        )
    }

    /// Net spending per expense category (expenses minus refunds), largest first (FR-012, FR-082).
    /// Categories netting to zero are omitted.
    public static func expenseBreakdown(
        of transactions: some Sequence<Transaction>,
        in period: ReportingPeriod,
        currency: CurrencyCode,
        accountIds: Set<UUID>? = nil
    ) -> [CategoryTotal] {
        var totals: [UUID?: Int64] = [:]
        for transaction in transactions where qualifies(transaction, period: period, currency: currency, accountIds: accountIds) {
            switch transaction.kind {
            case .expense: totals[transaction.categoryId, default: 0] += transaction.amount.minorUnits
            case .refund: totals[transaction.categoryId, default: 0] -= transaction.amount.minorUnits
            case .income, .transfer: break
            }
        }
        return totals
            .filter { $0.value != 0 }
            .map { CategoryTotal(categoryId: $0.key, amount: Money(minorUnits: $0.value, currency: currency)) }
            .sorted { lhs, rhs in
                lhs.amount.minorUnits != rhs.amount.minorUnits
                    ? lhs.amount.minorUnits > rhs.amount.minorUnits
                    : (lhs.categoryId?.uuidString ?? "") < (rhs.categoryId?.uuidString ?? "")
            }
    }

    private static func qualifies(_ transaction: Transaction, period: ReportingPeriod, currency: CurrencyCode, accountIds: Set<UUID>?) -> Bool {
        !transaction.isDeleted
            && transaction.amount.currency == currency
            && period.contains(transaction.occurredAt)
            && (accountIds?.contains(transaction.accountId) ?? true)
    }
}
