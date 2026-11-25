import Foundation
import MyExpenseCore
import Observation

/// Add/Edit transaction form (FR-020…FR-025, FR-043…FR-045, FR-053).
@MainActor
@Observable
public final class TransactionFormViewModel {
    /// The three choices shown in the segmented control. Refund is an expense option (ADR-004).
    public enum EntryType: String, CaseIterable, Identifiable, Sendable {
        case expense, income, transfer
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .expense: "Expense"
            case .income: "Income"
            case .transfer: "Transfer"
            }
        }
    }

    public var entryType: EntryType {
        didSet { if entryType != oldValue { entryTypeChanged() } }
    }
    public var isRefund = false
    public var amountText = ""
    public var accountId: UUID?
    public var destinationAccountId: UUID?
    public var categoryId: UUID?
    public var occurredAt: Date
    public var merchant = ""
    public var notes = ""
    public private(set) var saveError: String?

    public let isEditing: Bool
    public private(set) var accounts: [Account] = []
    private var allCategories: [TransactionCategory] = []
    private let original: Transaction?
    private let container: AppContainer
    /// Locale used for typing amounts; matches the decimal keypad's separator.
    private let locale: Locale

    public init(container: AppContainer, editing transaction: Transaction? = nil, initialType: EntryType = .expense, locale: Locale = .current) {
        self.container = container
        self.locale = locale
        original = transaction
        isEditing = transaction != nil
        occurredAt = transaction?.occurredAt ?? container.clock()
        entryType = initialType
        if let transaction {
            switch transaction.kind {
            case .income: entryType = .income
            case .expense: entryType = .expense
            case .refund: entryType = .expense; isRefund = true
            case .transfer: entryType = .transfer
            }
            amountText = Self.editableText(transaction.amount, locale: locale)
            accountId = transaction.accountId
            destinationAccountId = transaction.counterpartAccountId
            categoryId = transaction.categoryId
            merchant = transaction.merchant ?? ""
            notes = transaction.notes ?? ""
        }
        load()
    }

    public var title: String { isEditing ? "Edit Transaction" : "New Transaction" }
    public var hasAccounts: Bool { !accounts.isEmpty }
    public var currency: CurrencyCode {
        accountId.flatMap { id in accounts.first { $0.id == id }?.currency } ?? container.currency
    }

    /// Active categories of the right kind, plus the archived one already used when editing (FR-054).
    public var availableCategories: [TransactionCategory] {
        guard let kind = kind.requiredCategoryKind else { return [] }
        return allCategories.filter { $0.kind == kind && (!$0.isArchived || $0.id == original?.categoryId) }
    }

    public var kind: TransactionKind {
        switch entryType {
        case .income: .income
        case .expense: isRefund ? .refund : .expense
        case .transfer: .transfer
        }
    }

    /// First problem with the current input, phrased for the user; `nil` when the form can be saved.
    public var validationMessage: String? {
        switch makeTransaction() {
        case .success(let transaction):
            do {
                try validator().validate(transaction, original: original)
                return nil
            } catch {
                return Self.message(for: error)
            }
        case .failure(let message):
            return message
        }
    }

    public var canSave: Bool { validationMessage == nil }

    @discardableResult
    public func save() -> Bool {
        saveError = nil
        guard case .success(let transaction) = makeTransaction() else {
            saveError = validationMessage
            return false
        }
        do {
            try container.transactions.save(transaction, validator: validator())
            container.dataDidChange()
            return true
        } catch RepositoryError.validation(let error) {
            saveError = Self.message(for: error)
        } catch {
            saveError = "The transaction could not be saved. Please try again."
        }
        return false
    }

    // MARK: - Private

    private func load() {
        do {
            let all = try container.accounts.all(includeArchived: true)
            let referenced: Set<UUID> = [original?.accountId, original?.counterpartAccountId].reduce(into: []) { if let id = $1 { $0.insert(id) } }
            accounts = all.filter { !$0.isArchived || referenced.contains($0.id) }
            allCategories = try container.categories.all(includeArchived: true)
        } catch {
            saveError = "Accounts and categories could not be loaded."
        }
        if accountId == nil { accountId = accounts.first { !$0.isArchived }?.id }
        if entryType == .transfer && destinationAccountId == nil { destinationAccountId = defaultDestination() }
    }

    private func entryTypeChanged() {
        if entryType != .expense { isRefund = false }
        if entryType == .transfer {
            categoryId = nil
            if destinationAccountId == nil || destinationAccountId == accountId { destinationAccountId = defaultDestination() }
        } else {
            destinationAccountId = nil
            if let categoryId, !availableCategories.contains(where: { $0.id == categoryId }) { self.categoryId = nil }
        }
    }

    private func defaultDestination() -> UUID? {
        accounts.first { $0.id != accountId && !$0.isArchived }?.id
    }

    private func validator() -> TransactionValidator {
        TransactionValidator(accounts: accounts, categories: allCategories)
    }

    private enum Draft {
        case success(Transaction)
        case failure(String)
    }

    private func makeTransaction() -> Draft {
        guard let accountId else { return .failure(entryType == .transfer ? "Choose the account to transfer from." : "Choose an account.") }
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure("Enter an amount.") }
        guard let amount = try? Money(parsing: trimmed, currency: currency, locale: locale) else { return .failure("Enter a valid amount.") }
        let now = container.clock()
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(Transaction(
            id: original?.id ?? UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            occurredTimeZone: original?.occurredTimeZone ?? TimeZone.current.identifier,
            accountId: accountId,
            counterpartAccountId: entryType == .transfer ? destinationAccountId : nil,
            categoryId: entryType == .transfer ? nil : categoryId,
            merchant: entryType == .transfer || trimmedMerchant.isEmpty ? nil : trimmedMerchant,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            createdAt: original?.createdAt ?? now,
            updatedAt: now
        ))
    }

    static func editableText(_ money: Money, locale: Locale) -> String {
        "\(money.decimalValue)".replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    static func message(for error: TransactionValidationError) -> String {
        switch error {
        case .nonPositiveAmount: "Amount must be greater than zero."
        case .unknownAccount: "Choose an account."
        case .archivedAccount: "This account is archived. Choose another account."
        case .currencyMismatch: "Both accounts must use the same currency."
        case .missingCategory: "Choose a category."
        case .unknownCategory, .incompatibleCategory: "Choose a category that matches the transaction type."
        case .archivedCategory: "This category is archived. Choose another category."
        case .missingDestinationAccount: "Choose the account to transfer to."
        case .sameAccountTransfer: "Choose two different accounts for a transfer."
        case .transferHasCategory, .unexpectedDestinationAccount: "Check the transaction details."
        case .textTooLong: "Notes and payee must be \(TransactionValidator.maxTextLength) characters or fewer."
        }
    }
}
