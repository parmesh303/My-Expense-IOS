import Foundation
import MyExpenseCore
import Testing
@testable import MyExpenseFeatures

/// Shared setup: a profile, two INR accounts, one archived account and a few categories.
@MainActor
struct Phase2Fixture {
    let now: Date
    let container: AppContainer
    let bank = Account(name: "Bank", type: .bank, openingBalanceMinor: 10_000_00, sortOrder: 0)
    let cash = Account(name: "Cash", type: .cash, sortOrder: 1)
    let oldCard = Account(name: "Old Card", type: .creditCard, sortOrder: 2, archivedAt: Date(timeIntervalSince1970: 0))
    let food = TransactionCategory(name: "Food", kind: .expense, icon: "fork.knife", sortOrder: 0)
    let rent = TransactionCategory(name: "Rent", kind: .expense, icon: "house", sortOrder: 1)
    let salary = TransactionCategory(name: "Salary", kind: .income, icon: "briefcase", sortOrder: 0)

    init() throws {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
        self.now = now
        container = AppContainer.inMemory(profile: Profile(displayName: "P"), clock: { now })
        for account in [bank, cash, oldCard] { try container.accounts.save(account) }
        for category in [food, rent, salary] { try container.categories.save(category) }
    }

    @discardableResult
    func add(_ kind: TransactionKind, _ rupees: Int64, daysAgo: Int = 0, account: UUID? = nil, to: UUID? = nil, category: UUID? = nil, merchant: String? = nil) throws -> Transaction {
        let transaction = Transaction(
            kind: kind,
            amount: Money(minorUnits: rupees * 100, currency: .inr),
            occurredAt: now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
            accountId: account ?? bank.id,
            counterpartAccountId: to,
            categoryId: category,
            merchant: merchant
        )
        try container.transactions.save(transaction, validator: container.makeValidator())
        return transaction
    }
}

@MainActor
@Suite struct TransactionFormViewModelTests {
    let posix = Locale(identifier: "en_US_POSIX")

    @Test func newExpenseDefaultsAndSave() throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, locale: posix)
        #expect(sut.accountId == f.bank.id, "defaults to first active account")
        #expect(!sut.accounts.contains { $0.id == f.oldCard.id }, "archived accounts hidden for new entries")
        #expect(sut.availableCategories.map(\.name) == ["Food", "Rent"])
        #expect(sut.validationMessage == "Enter an amount.")

        sut.amountText = "250.5"
        #expect(sut.validationMessage == "Choose a category.")
        sut.categoryId = f.food.id
        sut.merchant = "  Swiggy  "
        #expect(sut.canSave)
        let versionBefore = f.container.dataVersion
        #expect(sut.save())
        #expect(f.container.dataVersion == versionBefore + 1)

        let saved = try #require(try f.container.transactions.allActive().first)
        #expect(saved.kind == .expense)
        #expect(saved.amount.minorUnits == 25_050)
        #expect(saved.merchant == "Swiggy")
        #expect(saved.notes == nil)
    }

    @Test(arguments: ["0", "-5", "abc"])
    func rejectsInvalidAmounts(text: String) throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, locale: posix)
        sut.categoryId = f.food.id
        sut.amountText = text
        #expect(!sut.canSave)
        #expect(!sut.save())
        #expect(try f.container.transactions.allActive().isEmpty)
    }

    @Test func switchingTypeResetsIncompatibleFields() throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, locale: posix)
        sut.categoryId = f.food.id
        sut.isRefund = true
        sut.entryType = .income
        #expect(sut.categoryId == nil)
        #expect(!sut.isRefund)
        #expect(sut.availableCategories.map(\.name) == ["Salary"])

        sut.entryType = .transfer
        #expect(sut.destinationAccountId == f.cash.id)
        #expect(sut.availableCategories.isEmpty)
    }

    @Test func transferToSameAccountIsRejected() throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, initialType: .transfer, locale: posix)
        sut.amountText = "100"
        #expect(sut.canSave)
        sut.destinationAccountId = f.bank.id
        #expect(sut.validationMessage == "Choose two different accounts for a transfer.")
        sut.destinationAccountId = f.cash.id
        #expect(sut.save())
        let saved = try #require(try f.container.transactions.allActive().first)
        #expect(saved.kind == .transfer && saved.categoryId == nil && saved.counterpartAccountId == f.cash.id)
    }

    @Test func refundToggleSavesRefundKind() throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, locale: posix)
        sut.isRefund = true
        sut.amountText = "40"
        sut.categoryId = f.food.id
        #expect(sut.save())
        #expect(try f.container.transactions.allActive().first?.kind == .refund)
    }

    @Test func editingPreservesIdentityAndUpdates() throws {
        let f = try Phase2Fixture()
        let original = try f.add(.refund, 75, category: f.food.id, merchant: "Amazon")
        let sut = TransactionFormViewModel(container: f.container, editing: original, locale: posix)
        #expect(sut.isEditing)
        #expect(sut.entryType == .expense && sut.isRefund)
        #expect(sut.amountText == "75")
        sut.amountText = "80"
        #expect(sut.save())
        let all = try f.container.transactions.allActive()
        #expect(all.count == 1)
        #expect(all.first?.id == original.id)
        #expect(all.first?.amount.minorUnits == 8_000)
        #expect(all.first?.createdAt == original.createdAt)
    }

    @Test func editingKeepsArchivedAccountUsedByHistory() throws {
        let f = try Phase2Fixture()
        let historical = Transaction(kind: .expense, amount: Money(minorUnits: 100, currency: .inr), accountId: f.oldCard.id, categoryId: f.food.id)
        try f.container.transactions.save(historical, validator: TransactionValidator(accounts: [f.oldCard.withArchived(nil)], categories: [f.food]))
        let sut = TransactionFormViewModel(container: f.container, editing: historical, locale: posix)
        #expect(sut.accounts.contains { $0.id == f.oldCard.id })
        sut.notes = "fixed"
        #expect(sut.save())
    }

    @Test func parsesLocaleDecimalSeparator() throws {
        let f = try Phase2Fixture()
        let sut = TransactionFormViewModel(container: f.container, locale: Locale(identifier: "de_DE"))
        sut.amountText = "1.234,50"
        sut.categoryId = f.food.id
        #expect(sut.save())
        #expect(try f.container.transactions.allActive().first?.amount.minorUnits == 123_450)
    }
}

extension Account {
    func withArchived(_ date: Date?) -> Account {
        var copy = self
        copy.archivedAt = date
        return copy
    }
}

@MainActor
@Suite struct TransactionListViewModelTests {
    @Test func emptyVersusNoResults() throws {
        let f = try Phase2Fixture()
        let sut = TransactionListViewModel(container: f.container)
        sut.reload()
        #expect(sut.state == .empty)

        try f.add(.expense, 10, category: f.food.id, merchant: "Cafe")
        sut.searchText = "zzz"
        sut.reload()
        #expect(sut.state == .noResults)
        sut.searchText = "caf"
        sut.reload()
        #expect(sut.state == .loaded)
        #expect(sut.rows.map(\.title) == ["Cafe"])
    }

    @Test func filtersAndSortAndAmountRange() throws {
        let f = try Phase2Fixture()
        try f.add(.expense, 100, daysAgo: 1, category: f.food.id)
        try f.add(.expense, 15_000, daysAgo: 2, category: f.rent.id)
        try f.add(.income, 50_000, daysAgo: 40, category: f.salary.id)
        try f.add(.transfer, 500, daysAgo: 0, to: f.cash.id)

        let sut = TransactionListViewModel(container: f.container)
        sut.filter.kinds = [.expense]
        sut.reload()
        #expect(sut.rows.count == 2)

        sut.filter = TransactionFilter()
        sut.filter.dateOption = .thisMonth
        sut.reload()
        #expect(sut.rows.count == 3)

        sut.filter = TransactionFilter()
        sut.filter.accountIds = [f.cash.id]
        sut.reload()
        #expect(sut.rows.map(\.title) == ["Transfer"])

        sut.filter = TransactionFilter()
        sut.filter.minAmountText = "200"
        sut.filter.maxAmountText = "20000"
        sut.sort = .amountAscending
        sut.reload()
        #expect(sut.rows.map(\.transaction.amount.minorUnits) == [500_00, 15_000_00])
        #expect(sut.sections.count == 1)
        #expect(sut.filter.activeCount == 1)

        sut.filter.minAmountText = "abc"
        sut.reload()
        #expect(sut.amountFilterError == "Enter valid amounts.")

        sut.clearFilters()
        #expect(sut.rows.count == 4)
    }

    @Test func pagingAndDaySections() throws {
        let f = try Phase2Fixture()
        for index in 0..<120 { try f.add(.expense, Int64(index + 1), daysAgo: index % 3, category: f.food.id) }
        let sut = TransactionListViewModel(container: f.container)
        sut.reload()
        #expect(sut.rows.count == 50)
        #expect(sut.hasMore)
        #expect(sut.sections.count == 2, "40 rows today + 10 from yesterday")

        sut.loadMoreIfNeeded(currentRow: sut.rows[10])
        #expect(sut.rows.count == 50, "only the last row triggers paging")
        sut.loadMoreIfNeeded(currentRow: sut.rows.last!)
        sut.loadMoreIfNeeded(currentRow: sut.rows.last!)
        #expect(sut.rows.count == 120)
        #expect(Set(sut.rows.map(\.id)).count == 120)
        #expect(!sut.hasMore)
        #expect(sut.sections.count == 3)
    }

    @Test func deleteIsSoftAndUpdatesBalances() throws {
        let f = try Phase2Fixture()
        let expense = try f.add(.expense, 100, category: f.food.id)
        let sut = TransactionListViewModel(container: f.container)
        sut.reload()
        #expect(sut.delete(id: expense.id))
        #expect(sut.rows.isEmpty)
        #expect(try f.container.transactions.transaction(id: expense.id)?.deletedAt != nil)

        let accounts = AccountsViewModel(container: f.container)
        accounts.load()
        #expect(accounts.active.first { $0.account.id == f.bank.id }?.balance.minorUnits == 10_000_00)
    }

    @Test func archivedCategoryKeepsHistoricalLabel() throws {
        let f = try Phase2Fixture()
        try f.add(.expense, 5, category: f.rent.id)
        try f.container.categories.setArchived(true, id: f.rent.id)
        let sut = TransactionListViewModel(container: f.container)
        sut.reload()
        #expect(sut.rows.first?.subtitle == "Rent (archived) · Bank")
    }
}

@MainActor
@Suite struct TransactionDetailViewModelTests {
    @Test func loadsAndDeletes() throws {
        let f = try Phase2Fixture()
        let transfer = try f.add(.transfer, 300, to: f.cash.id)
        let sut = TransactionDetailViewModel(container: f.container, transactionId: transfer.id)
        sut.load()
        #expect(sut.accountName == "Bank")
        #expect(sut.destinationName == "Cash")
        #expect(sut.delete())
        sut.load()
        #expect(sut.transaction == nil)
    }
}

@MainActor
@Suite struct ReceiptsViewModelTests {
    @Test func attachValidatesStoresAndRemoves() throws {
        let f = try Phase2Fixture()
        let transaction = try f.add(.expense, 10, category: f.food.id)
        let sut = ReceiptsViewModel(container: f.container, transactionId: transaction.id)
        sut.load()

        #expect(!sut.attach(data: Data([1]), typeIdentifier: "public.gif"))
        #expect(sut.errorMessage == "Only JPEG, PNG, HEIC images and PDF files can be attached.")

        let bytes = Data("fake-pdf".utf8)
        #expect(sut.attach(data: bytes, typeIdentifier: "com.adobe.pdf"))
        let receipt = try #require(sut.receipts.first)
        let url = sut.fileURL(for: receipt)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(receipt.fileName.hasSuffix(".pdf"))
        #expect(receipt.uploadState == .localOnly)

        sut.remove(receipt)
        #expect(sut.receipts.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func failedRecordSaveRemovesFile() throws {
        let f = try Phase2Fixture()
        let receipts = InMemoryReceiptRepository()
        let directory = FileManager.default.temporaryDirectory.appending(path: "receipts-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = AppContainer(
            profiles: f.container.profiles, accounts: f.container.accounts, categories: f.container.categories,
            transactions: f.container.transactions, receipts: receipts, receiptFiles: FileReceiptStore(directory: directory)
        )
        receipts.failNextSave = true
        let sut = ReceiptsViewModel(container: container, transactionId: UUID())
        #expect(!sut.attach(data: Data([0xFF]), typeIdentifier: "public.jpeg"))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        #expect(leftovers.isEmpty)
    }

    @Test func fileStoreCannotEscapeDirectory() {
        let store = FileReceiptStore(directory: URL(filePath: "/tmp/receipts"))
        #expect(store.url(for: "../../etc/passwd").path(percentEncoded: false) == "/tmp/receipts/passwd")
    }
}

@MainActor
@Suite struct AccountViewModelTests {
    let posix = Locale(identifier: "en_US_POSIX")

    @Test func createValidatesAndStoresCardDebtAsNegative() throws {
        let f = try Phase2Fixture()
        let sut = AccountFormViewModel(container: f.container, locale: posix)
        sut.name = "cash"
        #expect(!sut.save())
        #expect(sut.errorMessage == "An active account with this name already exists.")

        sut.name = "Amex"
        sut.type = .creditCard
        sut.openingBalanceText = "1500"
        #expect(sut.save())
        let amex = try #require(try f.container.accounts.all(includeArchived: false).first { $0.name == "Amex" })
        #expect(amex.openingBalanceMinor == -150_000)

        let edit = AccountFormViewModel(container: f.container, editing: amex, locale: posix)
        #expect(edit.openingBalanceText == "1500")
        #expect(edit.balanceLabel == "Amount owed")
    }

    @Test func archiveMovesAccountAndTotalsUseActiveOnly() throws {
        let f = try Phase2Fixture()
        try f.add(.expense, 1_000, category: f.food.id)
        let sut = AccountsViewModel(container: f.container)
        sut.load()
        #expect(sut.total.minorUnits == 9_000_00)
        sut.setArchived(true, accountId: f.bank.id)
        #expect(sut.archived.contains { $0.account.id == f.bank.id })
        #expect(sut.total.minorUnits == 0)
        sut.setArchived(false, accountId: f.bank.id)
        #expect(sut.active.contains { $0.account.id == f.bank.id })
    }
}

@MainActor
@Suite struct CategoryViewModelTests {
    @Test func createRenameAndDuplicateCheck() throws {
        let f = try Phase2Fixture()
        let create = CategoryFormViewModel(container: f.container, kind: .expense)
        create.name = "food"
        #expect(!create.save())
        create.name = "Pets"
        create.icon = "pawprint"
        #expect(create.save())

        let list = CategoriesViewModel(container: f.container)
        list.load()
        #expect(list.active.map(\.name) == ["Food", "Rent", "Pets"])

        let rename = CategoryFormViewModel(container: f.container, kind: .expense, editing: list.active[0])
        rename.name = "Dining"
        #expect(rename.save())
        list.load()
        #expect(list.active.first?.name == "Dining")
    }

    @Test func reorderPersists() throws {
        let f = try Phase2Fixture()
        let sut = CategoriesViewModel(container: f.container)
        sut.load()
        sut.move(fromOffsets: [1], toOffset: 0)
        #expect(sut.active.map(\.name) == ["Rent", "Food"])
        let reloaded = CategoriesViewModel(container: f.container)
        reloaded.load()
        #expect(reloaded.active.map(\.name) == ["Rent", "Food"])
    }

    @Test func archiveAndRestoreWithNameConflict() throws {
        let f = try Phase2Fixture()
        let sut = CategoriesViewModel(container: f.container)
        sut.load()
        sut.setArchived(true, categoryId: f.food.id)
        #expect(sut.archived.map(\.name) == ["Food"])

        let replacement = CategoryFormViewModel(container: f.container, kind: .expense)
        replacement.name = "Food"
        #expect(replacement.save())

        sut.setArchived(false, categoryId: f.food.id)
        #expect(sut.errorMessage == "An active category with this name already exists.")
        #expect(sut.archived.map(\.name) == ["Food"])
    }

    @Test func switchingKindReloads() throws {
        let f = try Phase2Fixture()
        let sut = CategoriesViewModel(container: f.container)
        sut.load()
        sut.kind = .income
        #expect(sut.active.map(\.name) == ["Salary"])
    }
}
