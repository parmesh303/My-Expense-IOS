import Foundation
import MyExpenseCore
import Observation

/// Accounts screen: balances, archive/unarchive (FR-040…FR-042, FR-047).
@MainActor
@Observable
public final class AccountsViewModel {
    public private(set) var active: [DashboardViewModel.AccountBalance] = []
    public private(set) var archived: [DashboardViewModel.AccountBalance] = []
    public private(set) var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    /// Net worth across active accounts in the profile currency (liabilities subtract).
    public var total: Money {
        let currency = container.currency
        let sum = active.filter { $0.balance.currency == currency }.reduce(Int64(0)) { $0 + $1.balance.minorUnits }
        return Money(minorUnits: sum, currency: currency)
    }

    public func load() {
        do {
            let transactions = try container.transactions.allActive()
            let all = try container.accounts.all(includeArchived: true).map {
                DashboardViewModel.AccountBalance(account: $0, balance: LedgerCalculator.balance(of: $0, transactions: transactions))
            }
            active = all.filter { !$0.account.isArchived }
            archived = all.filter { $0.account.isArchived }
            errorMessage = nil
        } catch {
            errorMessage = "Accounts could not be loaded."
        }
    }

    public func setArchived(_ archived: Bool, accountId: UUID) {
        do {
            try container.accounts.setArchived(archived, id: accountId)
            container.dataDidChange()
            load()
        } catch {
            errorMessage = "The account could not be updated."
        }
    }
}

/// Create/edit an account (FR-041, FR-042).
@MainActor
@Observable
public final class AccountFormViewModel {
    public var name: String
    public var type: AccountType
    /// For credit cards this is the amount owed (ADR-003).
    public var openingBalanceText: String
    public private(set) var errorMessage: String?

    public let isEditing: Bool
    private let original: Account?
    private let container: AppContainer
    private let locale: Locale

    public init(container: AppContainer, editing account: Account? = nil, locale: Locale = .current) {
        self.container = container
        self.locale = locale
        original = account
        isEditing = account != nil
        name = account?.name ?? ""
        type = account?.type ?? .bank
        if let account {
            let shown = account.type.isLiability ? -account.openingBalanceMinor : account.openingBalanceMinor
            openingBalanceText = TransactionFormViewModel.editableText(Money(minorUnits: shown, currency: account.currency), locale: locale)
        } else {
            openingBalanceText = ""
        }
    }

    public var title: String { isEditing ? "Edit Account" : "New Account" }
    public var currency: CurrencyCode { original?.currency ?? container.currency }
    public var balanceLabel: String { type.isLiability ? "Amount owed" : "Opening balance" }

    @discardableResult
    public func save() -> Bool {
        errorMessage = nil
        do {
            let existing = try container.accounts.all(includeArchived: true)
            let validName = try NameValidator.accountName(name, editing: original?.id, among: existing)
            let text = openingBalanceText.trimmingCharacters(in: .whitespaces)
            guard let money = try? Money(parsing: text.isEmpty ? "0" : text, currency: currency, locale: locale) else {
                errorMessage = "Enter a valid amount."
                return false
            }
            let now = container.clock()
            // Negative opening balances are allowed for overdrawn bank accounts; card debt is entered as positive.
            let opening = type.isLiability ? -money.minorUnits : money.minorUnits
            let account = Account(
                id: original?.id ?? UUID(),
                name: validName,
                type: type,
                currency: currency,
                openingBalanceMinor: opening,
                sortOrder: original?.sortOrder ?? existing.count,
                archivedAt: original?.archivedAt,
                createdAt: original?.createdAt ?? now,
                updatedAt: now
            )
            try container.accounts.save(account)
            container.dataDidChange()
            return true
        } catch let error as NameValidationError {
            errorMessage = NameValidationMessages.message(for: error, noun: "account")
        } catch {
            errorMessage = "The account could not be saved. Please try again."
        }
        return false
    }
}

enum NameValidationMessages {
    static func message(for error: NameValidationError, noun: String) -> String {
        switch error {
        case .empty: "Enter a name."
        case .tooLong(let max): "Name must be \(max) characters or fewer."
        case .duplicate: "An active \(noun) with this name already exists."
        }
    }
}
