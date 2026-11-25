import Foundation
import Testing
@testable import MyExpenseCore

@Suite struct ReportingPeriodTests {
    typealias F = Fixtures

    @Test func monthBoundariesInUserTimeZone() {
        let period = ReportingPeriod.containing(F.date(2026, 2, 14), granularity: .month, calendar: F.calendar)
        #expect(period.start == F.date(2026, 2, 1, 0, 0))
        #expect(period.end == F.date(2026, 3, 1, 0, 0))
        #expect(period.contains(F.date(2026, 2, 28, 23, 59)))
        #expect(!period.contains(F.date(2026, 3, 1, 0, 0)))
    }

    @Test func weekStartsOnConfiguredFirstWeekday() {
        // 25 Nov 2026 is a Wednesday; calendar first weekday is Monday.
        let period = ReportingPeriod.containing(F.date(2026, 11, 25), granularity: .week, calendar: F.calendar)
        #expect(period.start == F.date(2026, 11, 23, 0, 0))
        #expect(period.end == F.date(2026, 11, 30, 0, 0))
    }

    @Test func previousPeriod() {
        let march = ReportingPeriod.containing(F.date(2026, 3, 31), granularity: .month, calendar: F.calendar)
        let february = march.previous(calendar: F.calendar)
        #expect(february.start == F.date(2026, 2, 1, 0, 0))
        #expect(february.end == F.date(2026, 3, 1, 0, 0))
        #expect(february.next(calendar: F.calendar) == march)

        let year = ReportingPeriod.containing(F.date(2026, 6, 1), granularity: .year, calendar: F.calendar)
        #expect(year.previous(calendar: F.calendar).start == F.date(2025, 1, 1, 0, 0))
    }

    @Test func customRangeIncludesWholeLastDayAndPreviousHasSameLength() {
        let custom = ReportingPeriod.custom(from: F.date(2026, 11, 20, 15), through: F.date(2026, 11, 10, 9), calendar: F.calendar)
        #expect(custom.start == F.date(2026, 11, 10, 0, 0))
        #expect(custom.end == F.date(2026, 11, 21, 0, 0))
        #expect(custom.contains(F.date(2026, 11, 20, 23, 59)))
        let previous = custom.previous(calendar: F.calendar)
        #expect(previous.end == custom.start)
        #expect(previous.start == F.date(2026, 10, 30, 0, 0))
    }
}

@Suite struct TransactionQueryTests {
    typealias F = Fixtures
    let lunch = Transaction(kind: .expense, amount: Fixtures.inr(250), occurredAt: Fixtures.date(2026, 11, 3), accountId: Fixtures.cash.id, categoryId: Fixtures.food.id, merchant: "Cafe Coffee Day")
    let rentPaid = Transaction(kind: .expense, amount: Fixtures.inr(15_000), occurredAt: Fixtures.date(2026, 11, 1), accountId: Fixtures.bank.id, categoryId: Fixtures.rent.id, notes: "November rent")
    let salary = Transaction(kind: .income, amount: Fixtures.inr(80_000), occurredAt: Fixtures.date(2026, 10, 31), accountId: Fixtures.bank.id, categoryId: Fixtures.salary.id)
    let atm = Transaction(kind: .transfer, amount: Fixtures.inr(2_000), occurredAt: Fixtures.date(2026, 11, 2), accountId: Fixtures.bank.id, counterpartAccountId: Fixtures.cash.id)
    var all: [Transaction] { [lunch, rentPaid, salary, atm] }

    func run(_ query: TransactionQuery, names: [UUID: String] = [:]) -> [UUID] {
        all.filter { query.matches($0, categoryNames: names) }.sorted(by: query.areInIncreasingOrder).map(\.id)
    }

    @Test func searchMatchesMerchantNotesCategoryAndAmount() {
        var query = TransactionQuery()
        query.searchText = "coffee"
        #expect(run(query) == [lunch.id])
        query.searchText = "RENT"
        #expect(run(query) == [rentPaid.id])
        query.searchText = "Salary"
        #expect(run(query, names: [F.salary.id: "Salary"]) == [salary.id])
        query.searchText = "15000"
        #expect(run(query) == [rentPaid.id])
    }

    @Test func filtersByKindAccountCategoryDateAndAmount() {
        var query = TransactionQuery()
        query.kinds = [.expense]
        #expect(Set(run(query)) == [lunch.id, rentPaid.id])

        query = TransactionQuery()
        query.accountIds = [F.cash.id]
        #expect(Set(run(query)) == [lunch.id, atm.id], "transfer into cash matches")

        query = TransactionQuery()
        query.categoryIds = [F.food.id]
        #expect(run(query) == [lunch.id])

        query = TransactionQuery()
        query.dateRange = .containing(F.date(2026, 11, 15), granularity: .month, calendar: F.calendar)
        #expect(!run(query).contains(salary.id))

        query = TransactionQuery()
        query.minAmountMinor = 1_000_00
        query.maxAmountMinor = 20_000_00
        #expect(Set(run(query)) == [rentPaid.id, atm.id])
    }

    @Test func sortsByDateAndAmount() {
        var query = TransactionQuery()
        #expect(run(query) == [lunch.id, atm.id, rentPaid.id, salary.id])
        query.sort = .dateAscending
        #expect(run(query) == [salary.id, rentPaid.id, atm.id, lunch.id])
        query.sort = .amountDescending
        #expect(run(query) == [salary.id, rentPaid.id, atm.id, lunch.id])
        query.sort = .amountAscending
        #expect(run(query) == [lunch.id, atm.id, rentPaid.id, salary.id])
    }

    @Test func excludesDeletedByDefault() {
        var deleted = lunch
        deleted.deletedAt = .now
        #expect(!TransactionQuery().matches(deleted))
    }
}

@Suite @MainActor struct InMemoryTransactionRepositoryTests {
    typealias F = Fixtures
    let validator = TransactionValidator(accounts: [F.bank, F.cash], categories: [F.food])

    @Test func pagingReturnsEveryRowExactlyOnce() throws {
        let sameTime = F.date(2026, 11, 1)
        let transactions = (1...125).map {
            Transaction(kind: .expense, amount: F.inr(Int64($0)), occurredAt: $0.isMultiple(of: 3) ? sameTime : F.date(2026, 11, 1, 12, $0 % 60), accountId: F.bank.id, categoryId: F.food.id)
        }
        let repository = InMemoryTransactionRepository(transactions: transactions)
        var page = PageRequest(limit: 50)
        var seen: [UUID] = []
        while true {
            let batch = try repository.fetch(TransactionQuery(), page: page)
            if batch.isEmpty { break }
            seen += batch.map(\.id)
            page = page.next
        }
        #expect(seen.count == 125)
        #expect(Set(seen).count == 125)
    }

    @Test func saveValidatesAndDeleteIsSoft() throws {
        let fixedNow = F.date(2026, 11, 25)
        let repository = InMemoryTransactionRepository(clock: { fixedNow })
        let bad = Transaction(kind: .expense, amount: F.inr(0), accountId: F.bank.id, categoryId: F.food.id)
        #expect(throws: RepositoryError.validation(.nonPositiveAmount)) { try repository.save(bad, validator: validator) }

        let good = Transaction(kind: .expense, amount: F.inr(10), accountId: F.bank.id, categoryId: F.food.id, createdAt: F.date(2026, 11, 1))
        try repository.save(good, validator: validator)
        var edited = good
        edited.amount = F.inr(20)
        try repository.save(edited, validator: validator)
        let stored = try #require(try repository.transaction(id: good.id))
        #expect(stored.amount == F.inr(20))
        #expect(stored.createdAt == F.date(2026, 11, 1))
        #expect(stored.updatedAt == fixedNow)

        try repository.delete(id: good.id)
        #expect(try repository.allActive().isEmpty)
        #expect(try repository.transaction(id: good.id)?.deletedAt == fixedNow)
        #expect(throws: RepositoryError.notFound) { try repository.delete(id: UUID()) }
    }
}
