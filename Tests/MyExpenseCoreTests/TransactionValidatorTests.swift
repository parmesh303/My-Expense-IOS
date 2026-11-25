import Foundation
import Testing
@testable import MyExpenseCore

@Suite struct TransactionValidatorTests {
    typealias F = Fixtures
    let validator = TransactionValidator(
        accounts: [F.bank, F.cash, F.usdAccount, Account(id: archivedAccountId, name: "Old", type: .bank, archivedAt: .now)],
        categories: [F.food, F.salary, TransactionCategory(id: archivedCategoryId, name: "Old", kind: .expense, icon: "x", archivedAt: .now)]
    )
    static let archivedAccountId = UUID()
    static let archivedCategoryId = UUID()

    @Test func acceptsValidExpenseIncomeRefundTransfer() throws {
        try validator.validate(Transaction(kind: .expense, amount: F.inr(10), accountId: F.bank.id, categoryId: F.food.id))
        try validator.validate(Transaction(kind: .refund, amount: F.inr(10), accountId: F.bank.id, categoryId: F.food.id))
        try validator.validate(Transaction(kind: .income, amount: F.inr(10), accountId: F.bank.id, categoryId: F.salary.id))
        try validator.validate(Transaction(kind: .transfer, amount: F.inr(10), accountId: F.bank.id, counterpartAccountId: F.cash.id))
    }

    @Test(arguments: [Int64(0), -100])
    func rejectsNonPositiveAmount(minor: Int64) {
        let transaction = Transaction(kind: .expense, amount: Money(minorUnits: minor, currency: .inr), accountId: F.bank.id, categoryId: F.food.id)
        #expect(throws: TransactionValidationError.nonPositiveAmount) { try validator.validate(transaction) }
    }

    @Test func rejectsSameAccountTransfer() {
        let transaction = Transaction(kind: .transfer, amount: F.inr(1), accountId: F.bank.id, counterpartAccountId: F.bank.id)
        #expect(throws: TransactionValidationError.sameAccountTransfer) { try validator.validate(transaction) }
    }

    @Test func transferRules() {
        #expect(throws: TransactionValidationError.missingDestinationAccount) {
            try validator.validate(Transaction(kind: .transfer, amount: F.inr(1), accountId: F.bank.id))
        }
        #expect(throws: TransactionValidationError.transferHasCategory) {
            try validator.validate(Transaction(kind: .transfer, amount: F.inr(1), accountId: F.bank.id, counterpartAccountId: F.cash.id, categoryId: F.food.id))
        }
        #expect(throws: TransactionValidationError.currencyMismatch) {
            try validator.validate(Transaction(kind: .transfer, amount: F.inr(1), accountId: F.bank.id, counterpartAccountId: F.usdAccount.id))
        }
        #expect(throws: TransactionValidationError.unexpectedDestinationAccount) {
            try validator.validate(Transaction(kind: .expense, amount: F.inr(1), accountId: F.bank.id, counterpartAccountId: F.cash.id, categoryId: F.food.id))
        }
    }

    @Test func rejectsIncompatibleCategory() {
        #expect(throws: TransactionValidationError.incompatibleCategory) {
            try validator.validate(Transaction(kind: .expense, amount: F.inr(1), accountId: F.bank.id, categoryId: F.salary.id))
        }
        #expect(throws: TransactionValidationError.incompatibleCategory) {
            try validator.validate(Transaction(kind: .income, amount: F.inr(1), accountId: F.bank.id, categoryId: F.food.id))
        }
        #expect(throws: TransactionValidationError.missingCategory) {
            try validator.validate(Transaction(kind: .expense, amount: F.inr(1), accountId: F.bank.id))
        }
    }

    @Test func rejectsUnknownAccountAndCurrencyMismatch() {
        #expect(throws: TransactionValidationError.unknownAccount) {
            try validator.validate(Transaction(kind: .expense, amount: F.inr(1), accountId: UUID(), categoryId: F.food.id))
        }
        #expect(throws: TransactionValidationError.currencyMismatch) {
            try validator.validate(Transaction(kind: .expense, amount: F.inr(1), accountId: F.usdAccount.id, categoryId: F.food.id))
        }
    }

    @Test func archivedCategoryRejectedForNewButKeptForHistory() throws {
        let historical = Transaction(kind: .expense, amount: F.inr(5), accountId: F.bank.id, categoryId: Self.archivedCategoryId)
        #expect(throws: TransactionValidationError.archivedCategory) { try validator.validate(historical) }

        var edited = historical
        edited.notes = "fixed typo"
        try validator.validate(edited, original: historical)
    }

    @Test func archivedAccountRejectedForNewButKeptForHistory() throws {
        let historical = Transaction(kind: .expense, amount: F.inr(5), accountId: Self.archivedAccountId, categoryId: F.food.id)
        #expect(throws: TransactionValidationError.archivedAccount) { try validator.validate(historical) }
        try validator.validate(historical, original: historical)
    }
}
