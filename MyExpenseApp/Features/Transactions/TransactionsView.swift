import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Transactions tab: search, filter, sort, paging, delete (FR-026…FR-029, FR-032).
struct TransactionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: TransactionListViewModel?
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    TransactionList(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingForm = true
                    } label: {
                        Label("Add Transaction", systemImage: "plus")
                    }
                    .accessibilityIdentifier("transactions.add")
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
            if model == nil { model = TransactionListViewModel(container: container) }
            model?.reload()
        }
    }
}

private struct TransactionList: View {
    @Bindable var model: TransactionListViewModel
    @State private var showingFilters = false
    @State private var pendingDelete: TransactionPresenter.Row?

    var body: some View {
        content
            .searchable(text: $model.searchText, prompt: "Payee, notes, category or amount")
            .onChange(of: model.searchText) { model.reload() }
            .onChange(of: model.sort) { model.reload() }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Picker("Sort", selection: $model.sort) {
                        Text("Newest First").tag(TransactionSort.dateDescending)
                        Text("Oldest First").tag(TransactionSort.dateAscending)
                        Text("Highest Amount").tag(TransactionSort.amountDescending)
                        Text("Lowest Amount").tag(TransactionSort.amountAscending)
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        showingFilters = true
                    } label: {
                        Label(
                            model.filter.activeCount > 0 ? "Filters (\(model.filter.activeCount))" : "Filters",
                            systemImage: model.filter.activeCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .sheet(isPresented: $showingFilters, onDismiss: { model.reload() }) {
                TransactionFilterView(model: model)
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { row in
                Button("Delete", role: .destructive) { _ = model.delete(id: row.id) }
            } message: { row in
                Text("\(row.title) · \(row.transaction.amount.formatted()). Account balances and reports will be updated.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView(
                "No Transactions Yet",
                systemImage: "tray",
                description: Text("Tap + to record your first income, expense or transfer.")
            )
        case .noResults:
            ContentUnavailableView {
                Label("No Matches", systemImage: "magnifyingglass")
            } description: {
                Text("No transactions match your search or filters.")
            } actions: {
                if model.filter.activeCount > 0 {
                    Button("Clear Filters") { model.clearFilters() }
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { model.reload() }
            }
        case .loaded:
            List {
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            NavigationLink(value: row.id) {
                                TransactionRowView(row: row, showsDate: !model.isGroupedByDay)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = row }
                            }
                            .onAppear { model.loadMoreIfNeeded(currentRow: row) }
                        }
                    } header: {
                        if model.isGroupedByDay {
                            Text(section.day, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        }
                    }
                }
                if model.hasMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
        }
    }
}
