import Foundation
import MyExpenseCore
import Testing
@testable import MyExpenseFeatures

@MainActor
@Suite struct OnboardingViewModelTests {
    let now = Date(timeIntervalSince1970: 1_795_000_000)

    func makeSUT() -> (OnboardingViewModel, AppContainer) {
        let fixedNow = now
        let container = AppContainer.inMemory(clock: { fixedNow })
        return (OnboardingViewModel(container: container), container)
    }

    @Test func storageStepRequiresAcknowledgingLocalOnlyRisk() {
        let (sut, _) = makeSUT()
        sut.next()
        #expect(sut.step == .storage)
        #expect(!sut.canContinue)
        sut.next()
        #expect(sut.step == .storage)
        sut.acknowledgedLocalOnlyRisk = true
        sut.next()
        #expect(sut.step == .preferences)
    }

    @Test func cloudModeCannotBeChosenBeforeSyncExists() {
        let (sut, _) = makeSUT()
        sut.step = .storage
        sut.acknowledgedLocalOnlyRisk = true
        sut.storageMode = .cloud
        #expect(!sut.canContinue)
    }

    @Test func preferencesRequireName() {
        let (sut, _) = makeSUT()
        sut.step = .preferences
        sut.displayName = "  "
        #expect(!sut.canContinue)
        sut.displayName = "Parmesh"
        #expect(sut.canContinue)
    }

    @Test func finishSeedsCategoriesCreatesAccountAndSavesProfile() throws {
        let (sut, container) = makeSUT()
        sut.displayName = "  Parmesh "
        sut.accountName = "HDFC"
        sut.accountType = .bank
        sut.openingBalanceText = "25,000.50"

        #expect(sut.finish())
        #expect(container.profile?.displayName == "Parmesh")
        #expect(container.profile?.storageMode == .localOnly)
        let accounts = try container.accounts.all(includeArchived: true)
        #expect(accounts.count == 1)
        #expect(accounts.first?.openingBalanceMinor == 2_500_050)
        #expect(try container.categories.all(includeArchived: true).count == DefaultCategories.make().count)
    }

    @Test func creditCardOpeningBalanceIsStoredAsOwed() throws {
        let (sut, container) = makeSUT()
        sut.displayName = "P"
        sut.accountName = "Visa"
        sut.accountType = .creditCard
        sut.openingBalanceText = "3000"
        #expect(sut.finish())
        #expect(try container.accounts.all(includeArchived: true).first?.openingBalanceMinor == -300_000)
    }

    @Test func invalidOpeningBalanceShowsErrorAndSavesNothing() throws {
        let (sut, container) = makeSUT()
        sut.displayName = "P"
        sut.openingBalanceText = "abc"
        #expect(!sut.finish())
        #expect(sut.errorMessage == "Enter a valid opening balance.")
        #expect(container.profile == nil)
        #expect(try container.accounts.all(includeArchived: true).isEmpty)
    }

    @Test func skippingFirstAccount() throws {
        let (sut, container) = makeSUT()
        sut.displayName = "P"
        sut.createFirstAccount = false
        sut.openingBalanceText = "not used"
        #expect(sut.finish())
        #expect(try container.accounts.all(includeArchived: true).isEmpty)
        #expect(container.profile != nil)
    }
}

@MainActor
@Suite struct DashboardViewModelTests {
    let now: Date
    let calendar: Calendar
    let container: AppContainer
    let bank = Account(name: "Bank", type: .bank, openingBalanceMinor: 1_000_00)
    let card = Account(name: "Card", type: .creditCard)
    let food = TransactionCategory(name: "Food", kind: .expense, icon: "fork.knife")
    let salary = TransactionCategory(name: "Salary", kind: .income, icon: "briefcase")

    init() throws {
        var calendar = Calendar.current
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        self.calendar = calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
        self.now = now
        container = AppContainer.inMemory(profile: Profile(displayName: "P"), clock: { now })
        try container.accounts.save(bank)
        try container.accounts.save(card)
        try container.categories.save(food)
        try container.categories.save(salary)
    }

    func add(_ kind: TransactionKind, _ rupees: Int64, daysAgo: Int = 0, account: UUID? = nil, to: UUID? = nil, category: UUID? = nil, merchant: String? = nil) throws {
        let transaction = Transaction(
            kind: kind,
            amount: Money(minorUnits: rupees * 100, currency: .inr),
            occurredAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
            accountId: account ?? bank.id,
            counterpartAccountId: to,
            categoryId: category,
            merchant: merchant
        )
        try container.transactions.save(transaction, validator: container.makeValidator())
    }

    @Test func emptyStateStillShowsOpeningBalances() {
        let sut = DashboardViewModel(container: container)
        sut.load()
        #expect(sut.state == .empty)
        #expect(sut.balances.map(\.balance.minorUnits) == [1_000_00, 0])
    }

    @Test func totalsExcludeTransfersAndBalancesAreDerived() throws {
        try add(.income, 500, category: salary.id)
        try add(.expense, 200, account: card.id, category: food.id, merchant: "Swiggy")
        try add(.transfer, 150, to: card.id)

        let sut = DashboardViewModel(container: container)
        sut.load()
        #expect(sut.state == .loaded)
        #expect(sut.summary.income.minorUnits == 500_00)
        #expect(sut.summary.expenses.minorUnits == 200_00)
        #expect(sut.summary.netCashFlow.minorUnits == 300_00)
        let balances = Dictionary(uniqueKeysWithValues: sut.balances.map { ($0.account.id, $0.balance.minorUnits) })
        #expect(balances[bank.id] == 1_350_00)
        #expect(balances[card.id] == -50_00)
        #expect(sut.topCategories.map(\.name) == ["Food"])
        #expect(sut.recent.count == 3)
        #expect(sut.recent.contains { $0.title == "Swiggy" && $0.subtitle == "Food · Card" })
        #expect(sut.recent.contains { $0.title == "Transfer" && $0.subtitle == "Bank → Card" })
    }

    @Test func periodNavigation() throws {
        try add(.expense, 70, daysAgo: 40, category: food.id)
        let sut = DashboardViewModel(container: container)
        sut.load()
        #expect(sut.summary.expenses.minorUnits == 0)
        #expect(!sut.canGoForward)

        sut.showPrevious()
        #expect(sut.canGoForward)
        #expect(sut.summary.expenses.minorUnits == 70_00)

        sut.select(.year)
        #expect(sut.summary.expenses.minorUnits == 70_00)
        #expect(sut.period.granularity == .year)
    }

    @Test func dataChangeIncrementsVersion() throws {
        let before = container.dataVersion
        container.dataDidChange()
        #expect(container.dataVersion == before + 1)
    }
}

@MainActor
@Suite struct SettingsViewModelTests {
    @Test func savesValidatedChanges() {
        let container = AppContainer.inMemory(profile: Profile(displayName: "Old"))
        let sut = SettingsViewModel(container: container)
        #expect(!sut.hasChanges)
        sut.displayName = ""
        sut.save()
        #expect(sut.errorMessage == "Please enter your name.")
        #expect(container.profile?.displayName == "Old")

        sut.displayName = "New"
        sut.currency = .usd
        #expect(sut.hasChanges)
        sut.save()
        #expect(sut.errorMessage == nil)
        #expect(container.profile?.displayName == "New")
        #expect(container.profile?.preferredCurrency == .usd)
    }
}
