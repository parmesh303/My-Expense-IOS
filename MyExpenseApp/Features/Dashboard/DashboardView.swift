import Charts
import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Home tab (FR-010…FR-016).
struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: DashboardViewModel?
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingForm = true
                    } label: {
                        Label("Add Transaction", systemImage: "plus")
                    }
                    .accessibilityIdentifier("home.add")
                }
            }
            .sheet(isPresented: $showingForm) {
                TransactionFormView(container: container)
            }
            .navigationDestination(for: UUID.self) { id in
                TransactionDetailView(container: container, transactionId: id)
            }
        }
        .task(id: container.dataVersion) {
            if model == nil { model = DashboardViewModel(container: container) }
            model?.load()
        }
    }

    private var greeting: String {
        guard let name = container.profile?.displayName, !name.isEmpty else { return "Home" }
        return "Hi, \(name)"
    }

    @ViewBuilder
    private func content(_ model: DashboardViewModel) -> some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { model.load() }
            }
        case .empty, .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    PeriodHeader(model: model)
                    SummaryCard(summary: model.summary)
                    if model.state == .empty {
                        ContentUnavailableView {
                            Label("No Transactions Yet", systemImage: "tray")
                        } description: {
                            Text("Record income, expenses and transfers to see totals for the selected period.")
                        } actions: {
                            Button("Add Transaction") { showingForm = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .cardStyle()
                    } else {
                        if !model.topCategories.isEmpty {
                            CategorySpendingCard(categories: model.topCategories)
                        }
                        RecentTransactionsCard(recent: model.recent)
                    }
                    if !model.balances.isEmpty {
                        AccountsCard(balances: model.balances)
                    }
                }
                .padding()
            }
        }
    }
}

private struct PeriodHeader: View {
    let model: DashboardViewModel

    var body: some View {
        HStack {
            Button { model.showPrevious() } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous period")

            Menu {
                ForEach(PeriodGranularity.allCases, id: \.self) { granularity in
                    Button(granularity.title) { model.select(granularity) }
                }
            } label: {
                Text(model.periodTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityHint("Choose day, week, month or year")

            Button { model.showNext() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)
            .accessibilityLabel("Next period")
        }
    }
}

private struct SummaryCard: View {
    let summary: PeriodSummary

    var body: some View {
        HStack(alignment: .top) {
            SummaryFigure(title: "Income", value: summary.income.formatted(), systemImage: "arrow.down.circle", tint: Theme.income)
            SummaryFigure(title: "Spent", value: summary.netSpending.formatted(), systemImage: "arrow.up.circle", tint: Theme.expense)
            SummaryFigure(title: "Net", value: summary.netCashFlow.formatted(), systemImage: "equal.circle", tint: summary.netCashFlow.minorUnits < 0 ? Theme.expense : .primary)
        }
        .cardStyle()
    }
}

private struct CategorySpendingCard: View {
    let categories: [DashboardViewModel.CategorySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Top Spending").font(.headline)
            HStack(spacing: Theme.Spacing.l) {
                // Chart amounts are converted to Double for display only.
                Chart(categories) { item in
                    SectorMark(angle: .value("Amount", Double(item.amount.minorUnits)), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color(hex: item.colorHex) ?? Theme.accent)
                }
                .frame(width: 110, height: 110)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(categories) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundStyle(Color(hex: item.colorHex) ?? Theme.accent)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            Text(item.name).lineLimit(1)
                            Spacer()
                            Text(item.amount.formatted()).monospacedDigit()
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct RecentTransactionsCard: View {
    let recent: [TransactionPresenter.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Recent").font(.headline)
            ForEach(recent) { row in
                NavigationLink(value: row.id) {
                    TransactionRowView(row: row, showsDate: true)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

private struct AccountsCard: View {
    let balances: [DashboardViewModel.AccountBalance]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Accounts").font(.headline)
            ForEach(balances) { item in
                HStack {
                    Label(item.account.name, systemImage: item.account.type.systemImage)
                    Spacer()
                    BalanceText(balance: item.balance, accountType: item.account.type)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }
}

extension PeriodGranularity {
    var title: String {
        switch self {
        case .day: "Today"
        case .week: "This Week"
        case .month: "This Month"
        case .year: "This Year"
        }
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(AppContainer.inMemory(profile: Profile(displayName: "Parmesh")))
    }
}
#endif
