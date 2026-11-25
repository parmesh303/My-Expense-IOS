import Foundation
import MyExpenseCore
import Observation

/// User-editable filter state for the transaction list (FR-027).
public struct TransactionFilter: Equatable, Sendable {
    public enum DateOption: String, CaseIterable, Identifiable, Sendable {
        case all, thisMonth, lastMonth, thisYear, custom
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .all: "All Time"
            case .thisMonth: "This Month"
            case .lastMonth: "Last Month"
            case .thisYear: "This Year"
            case .custom: "Custom Range"
            }
        }
    }

    public var dateOption: DateOption = .all
    public var customStart: Date = .now
    public var customEnd: Date = .now
    public var kinds: Set<TransactionKind> = []
    public var accountIds: Set<UUID> = []
    public var categoryIds: Set<UUID> = []
    public var minAmountText = ""
    public var maxAmountText = ""

    public init() {}

    /// Number of active filter groups, for the toolbar badge.
    public var activeCount: Int {
        [dateOption != .all, !kinds.isEmpty, !accountIds.isEmpty, !categoryIds.isEmpty,
         !minAmountText.trimmingCharacters(in: .whitespaces).isEmpty || !maxAmountText.trimmingCharacters(in: .whitespaces).isEmpty]
            .filter { $0 }.count
    }

    func dateRange(now: Date, calendar: Calendar) -> ReportingPeriod? {
        switch dateOption {
        case .all: nil
        case .thisMonth: .containing(now, granularity: .month, calendar: calendar)
        case .lastMonth: ReportingPeriod.containing(now, granularity: .month, calendar: calendar).previous(calendar: calendar)
        case .thisYear: .containing(now, granularity: .year, calendar: calendar)
        case .custom: .custom(from: customStart, through: customEnd, calendar: calendar)
        }
    }
}

/// Transaction list with search, filters, sorting and incremental loading (FR-026…FR-029, FR-032).
@MainActor
@Observable
public final class TransactionListViewModel {
    public struct Section: Identifiable, Hashable, Sendable {
        public let day: Date
        public let rows: [TransactionPresenter.Row]
        public var id: Date { day }
    }

    public enum State: Equatable, Sendable {
        case loading, empty, noResults, loaded, failed(String)
    }

    public static let pageSize = 50

    public var searchText = ""
    public var filter = TransactionFilter()
    public var sort: TransactionSort = .dateDescending
    public private(set) var rows: [TransactionPresenter.Row] = []
    public private(set) var state: State = .loading
    public private(set) var hasMore = false
    public private(set) var amountFilterError: String?
    public private(set) var accounts: [Account] = []
    public private(set) var categories: [TransactionCategory] = []

    private var nextPage = PageRequest(limit: TransactionListViewModel.pageSize)
    private var presenter = TransactionPresenter(accounts: [], categories: [])
    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    /// Rows grouped by calendar day. Only date sorts are grouped; amount sorts use a single section.
    public var sections: [Section] {
        guard sort == .dateDescending || sort == .dateAscending else {
            return rows.isEmpty ? [] : [Section(day: .distantPast, rows: rows)]
        }
        let calendar = container.calendar
        var result: [Section] = []
        for row in rows {
            let day = calendar.startOfDay(for: row.transaction.occurredAt)
            if let last = result.last, last.day == day {
                result[result.count - 1] = Section(day: day, rows: last.rows + [row])
            } else {
                result.append(Section(day: day, rows: [row]))
            }
        }
        return result
    }

    public var isGroupedByDay: Bool { sort == .dateDescending || sort == .dateAscending }

    /// Reloads from the first page. Call after any change to search, filter or sort.
    public func reload() {
        do {
            presenter = try TransactionPresenter(container: container)
            accounts = presenter.accounts.values.sorted { ($0.isArchived ? 1 : 0, $0.sortOrder, $0.name) < ($1.isArchived ? 1 : 0, $1.sortOrder, $1.name) }
            categories = presenter.categories.values.sorted { ($0.kind.rawValue, $0.sortOrder, $0.name) < ($1.kind.rawValue, $1.sortOrder, $1.name) }
            nextPage = PageRequest(limit: Self.pageSize)
            rows = []
            try loadNextPage()
            if rows.isEmpty {
                let anyExist = !(try container.transactions.fetch(TransactionQuery(), page: PageRequest(limit: 1))).isEmpty
                state = anyExist ? .noResults : .empty
            } else {
                state = .loaded
            }
        } catch {
            state = .failed("Transactions could not be loaded. Please try again.")
        }
    }

    /// Loads the next page when the given row is the last one shown.
    public func loadMoreIfNeeded(currentRow: TransactionPresenter.Row) {
        guard hasMore, currentRow.id == rows.last?.id else { return }
        do {
            try loadNextPage()
        } catch {
            state = .failed("More transactions could not be loaded.")
        }
    }

    /// Soft-deletes a transaction (the view asks for confirmation first, FR-029).
    public func delete(id: UUID) -> Bool {
        do {
            try container.transactions.delete(id: id)
            rows.removeAll { $0.id == id }
            container.dataDidChange()
            return true
        } catch {
            state = .failed("The transaction could not be deleted.")
            return false
        }
    }

    public func clearFilters() {
        filter = TransactionFilter()
        reload()
    }

    public func makeQuery() -> TransactionQuery {
        var query = TransactionQuery()
        query.searchText = searchText
        query.sort = sort
        query.kinds = filter.kinds
        query.accountIds = filter.accountIds
        query.categoryIds = filter.categoryIds
        query.dateRange = filter.dateRange(now: container.clock(), calendar: container.calendar)
        amountFilterError = nil
        let currency = container.currency
        func parse(_ text: String) -> Int64? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            guard let money = try? Money(parsing: trimmed, currency: currency, locale: .current), money.minorUnits >= 0 else {
                amountFilterError = "Enter valid amounts."
                return nil
            }
            return money.minorUnits
        }
        query.minAmountMinor = parse(filter.minAmountText)
        query.maxAmountMinor = parse(filter.maxAmountText)
        return query
    }

    private func loadNextPage() throws {
        let page = try container.transactions.fetch(makeQuery(), page: nextPage)
        rows += page.map(presenter.row(for:))
        hasMore = page.count == nextPage.limit
        nextPage = nextPage.next
    }
}
