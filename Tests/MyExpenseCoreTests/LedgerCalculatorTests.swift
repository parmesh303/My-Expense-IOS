import Foundation
import Testing
@testable import MyExpenseCore

@Suite struct LedgerCalculatorTests {
    typealias F = Fixtures
    let november = ReportingPeriod.containing(F.date(2026, 11, 15), granularity: .month, calendar: F.calendar)

    @Test func incomeAndExpenseChangeBalance() {
        let transactions = [
            Transaction(kind: .income, amount: F.inr(50_000), accountId: F.bank.id, categoryId: F.salary.id),
            Transaction(kind: .expense, amount: F.inr(1_200), accountId: F.bank.id, categoryId: F.food.id),
        ]
        #expect(LedgerCalculator.balance(of: F.bank, transactions: transactions) == F.inr(10_000 + 50_000 - 1_200))
        #expect(LedgerCalculator.balance(of: F.cash, transactions: transactions) == F.inr(500))
    }

    @Test func transferMovesBalances() {
        let transfer = Transaction(kind: .transfer, amount: F.inr(300), occurredAt: F.date(2026, 11, 2), accountId: F.bank.id, counterpartAccountId: F.cash.id)
        #expect(LedgerCalculator.balance(of: F.bank, transactions: [transfer]) == F.inr(9_700))
        #expect(LedgerCalculator.balance(of: F.cash, transactions: [transfer]) == F.inr(800))
    }

    @Test func transfersExcludedFromTotals() {
        let transactions = [
            Transaction(kind: .transfer, amount: F.inr(300), occurredAt: F.date(2026, 11, 2), accountId: F.bank.id, counterpartAccountId: F.cash.id),
            Transaction(kind: .expense, amount: F.inr(100), occurredAt: F.date(2026, 11, 3), accountId: F.cash.id, categoryId: F.food.id),
        ]
        let summary = LedgerCalculator.summary(of: transactions, in: november, currency: .inr)
        #expect(summary.income == F.inr(0))
        #expect(summary.expenses == F.inr(100))
        #expect(summary.netCashFlow == F.inr(-100))
    }

    @Test func creditCardPurchaseAndPayment() {
        // Card starts with ₹2,000 owed. Buy ₹1,500 on card, then pay ₹3,500 from bank.
        let purchase = Transaction(kind: .expense, amount: F.inr(1_500), occurredAt: F.date(2026, 11, 5), accountId: F.card.id, categoryId: F.food.id)
        let payment = Transaction(kind: .transfer, amount: F.inr(3_500), occurredAt: F.date(2026, 11, 20), accountId: F.bank.id, counterpartAccountId: F.card.id)
        let transactions = [purchase, payment]

        #expect(LedgerCalculator.balance(of: F.card, transactions: transactions) == F.inr(0))
        #expect(LedgerCalculator.balance(of: F.bank, transactions: transactions) == F.inr(6_500))
        // Spending counted once (at purchase), payment is not an expense.
        #expect(LedgerCalculator.summary(of: transactions, in: november, currency: .inr).expenses == F.inr(1_500))
        #expect(LedgerCalculator.balance(of: F.card, transactions: transactions, asOf: F.date(2026, 11, 10)) == F.inr(-3_500))
    }

    @Test func refundReducesSpending() {
        let transactions = [
            Transaction(kind: .expense, amount: F.inr(2_000), occurredAt: F.date(2026, 11, 1), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .refund, amount: F.inr(500), occurredAt: F.date(2026, 11, 4), accountId: F.bank.id, categoryId: F.food.id),
        ]
        let summary = LedgerCalculator.summary(of: transactions, in: november, currency: .inr)
        #expect(summary.income == F.inr(0))
        #expect(summary.netSpending == F.inr(1_500))
        #expect(LedgerCalculator.balance(of: F.bank, transactions: transactions) == F.inr(8_500))
        #expect(LedgerCalculator.expenseBreakdown(of: transactions, in: november, currency: .inr)
            == [CategoryTotal(categoryId: F.food.id, amount: F.inr(1_500))])
    }

    @Test func deletedTransactionsIgnored() {
        let deleted = Transaction(kind: .expense, amount: F.inr(999), occurredAt: F.date(2026, 11, 1), accountId: F.bank.id, categoryId: F.food.id, deletedAt: .now)
        #expect(LedgerCalculator.balance(of: F.bank, transactions: [deleted]) == F.inr(10_000))
        #expect(LedgerCalculator.summary(of: [deleted], in: november, currency: .inr).expenses == F.inr(0))
    }

    @Test func summaryTotalsRespectPeriodBoundariesAndAccountFilter() {
        let transactions = [
            Transaction(kind: .expense, amount: F.inr(1), occurredAt: F.date(2026, 10, 31, 23, 59), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .expense, amount: F.inr(2), occurredAt: F.date(2026, 11, 1, 0, 0), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .expense, amount: F.inr(4), occurredAt: F.date(2026, 11, 30, 23, 59), accountId: F.cash.id, categoryId: F.food.id),
            Transaction(kind: .expense, amount: F.inr(8), occurredAt: F.date(2026, 12, 1, 0, 0), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .income, amount: F.inr(100), occurredAt: F.date(2026, 11, 10), accountId: F.bank.id, categoryId: F.salary.id),
        ]
        let all = LedgerCalculator.summary(of: transactions, in: november, currency: .inr)
        #expect(all.expenses == F.inr(6))
        #expect(all.income == F.inr(100))
        #expect(all.netCashFlow == F.inr(94))

        let bankOnly = LedgerCalculator.summary(of: transactions, in: november, currency: .inr, accountIds: [F.bank.id])
        #expect(bankOnly.expenses == F.inr(2))
    }

    @Test func categoryBreakdownSortedLargestFirst() {
        let transactions = [
            Transaction(kind: .expense, amount: F.inr(100), occurredAt: F.date(2026, 11, 1), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .expense, amount: F.inr(15_000), occurredAt: F.date(2026, 11, 1), accountId: F.bank.id, categoryId: F.rent.id),
            Transaction(kind: .expense, amount: F.inr(50), occurredAt: F.date(2026, 11, 2), accountId: F.bank.id, categoryId: F.food.id),
            Transaction(kind: .income, amount: F.inr(9_999), occurredAt: F.date(2026, 11, 2), accountId: F.bank.id, categoryId: F.salary.id),
        ]
        let breakdown = LedgerCalculator.expenseBreakdown(of: transactions, in: november, currency: .inr)
        #expect(breakdown.map(\.categoryId) == [F.rent.id, F.food.id])
        #expect(breakdown.map(\.amount) == [F.inr(15_000), F.inr(150)])
    }

    @Test func editingTransactionRecalculatesBalance() {
        var transaction = Transaction(kind: .expense, amount: F.inr(100), accountId: F.bank.id, categoryId: F.food.id)
        #expect(LedgerCalculator.balance(of: F.bank, transactions: [transaction]) == F.inr(9_900))
        transaction.accountId = F.cash.id
        #expect(LedgerCalculator.balance(of: F.bank, transactions: [transaction]) == F.inr(10_000))
        #expect(LedgerCalculator.balance(of: F.cash, transactions: [transaction]) == F.inr(400))
    }
}
