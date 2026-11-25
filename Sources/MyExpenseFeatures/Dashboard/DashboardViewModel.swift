import Foundation
import MyExpenseCore
import Observation

/// Home tab state (FR-010…FR-016). All figures come from persisted data via `LedgerCalculator`.
@MainActor
@Observable
public final class DashboardViewModel {
    public struct AccountBalance: Identifiable, Hashable, Sendable {
        public let account: Account
        public let balance: Money
        public var id: UUID { account.id }
    }

    public struct CategorySpending: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let icon: String
        public let colorHex: String?
        public let amount: Money
    }

    public enum State: Equatable, Sendable {
        case loading, empty, loaded, failed(String)
    }

    public static let recentLimit = 10
    public static let topCategoryLimit = 5

    public private(set) var state: State = .loading
    public private(set) var period: ReportingPeriod
    public private(set) var summary: PeriodSummary
    public private(set) var balances: [AccountBalance] = []
    public private(set) var topCategories: [CategorySpending] = []
    public private(set) var recent: [TransactionPresenter.Row] = []

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
        let period = ReportingPeriod.containing(container.clock(), granularity: .month, calendar: container.calendar)
        self.period = period
        summary = LedgerCalculator.summary(of: [], in: period, currency: container.currency)
    }

    public var periodTitle: String {
        let calendar = container.calendar
        let style = Date.FormatStyle(timeZone: calendar.timeZone)
        switch period.granularity {
        case .month: return period.start.formatted(style.month(.wide).year())
        case .year: return period.start.formatted(style.year())
        case .day: return period.start.formatted(style.day().month(.abbreviated).year())
        case .week, nil:
            let lastDay = period.end.addingTimeInterval(-1)
            return "\(period.start.formatted(style.day().month(.abbreviated))) – \(lastDay.formatted(style.day().month(.abbreviated).year()))"
        }
    }

    public var canGoForward: Bool { period.end <= container.clock() }

    public func select(_ granularity: PeriodGranularity) {
        period = .containing(container.clock(), granularity: granularity, calendar: container.calendar)
        load()
    }

    public func showPrevious() {
        period = period.previous(calendar: container.calendar)
        load()
    }

    public func showNext() {
        guard canGoForward else { return }
        period = period.next(calendar: container.calendar)
        load()
    }

    public func load() {
        do {
            let currency = container.currency
            let accounts = try container.accounts.all(includeArchived: false)
            let categories = try container.categories.all(includeArchived: true)
            let all = try container.transactions.allActive()

            summary = LedgerCalculator.summary(of: all, in: period, currency: currency)
            balances = accounts.map { AccountBalance(account: $0, balance: LedgerCalculator.balance(of: $0, transactions: all)) }

            // Empty state (FR-014) still shows account balances so opening balances are visible.
            if all.isEmpty {
                topCategories = []
                recent = []
                state = .empty
                return
            }

            let categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            topCategories = LedgerCalculator.expenseBreakdown(of: all, in: period, currency: currency)
                .filter { $0.amount.isPositive }
                .prefix(Self.topCategoryLimit)
                .map { total in
                    let category = total.categoryId.flatMap { categoriesById[$0] }
                    return CategorySpending(
                        id: total.categoryId?.uuidString ?? "uncategorized",
                        name: category?.name ?? "Uncategorized",
                        icon: category?.icon ?? "questionmark.circle",
                        colorHex: category?.colorHex,
                        amount: total.amount
                    )
                }

            let presenter = TransactionPresenter(accounts: try container.accounts.all(includeArchived: true), categories: categories)
            recent = try container.transactions
                .fetch(TransactionQuery(), page: PageRequest(limit: Self.recentLimit))
                .map(presenter.row(for:))
            state = .loaded
        } catch {
            state = .failed("Your data could not be loaded. Please try again.")
        }
    }
}
