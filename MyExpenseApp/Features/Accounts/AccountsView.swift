import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Accounts list with derived balances, archive/unarchive (S7, FR-040…FR-047).
struct AccountsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: AccountsViewModel?
    @State private var editing: Account?
    @State private var creating = false

    var body: some View {
        Group {
            if let model {
                list(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Label("Add Account", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $creating) { AccountFormView(container: container, account: nil) }
        .sheet(item: $editing) { AccountFormView(container: container, account: $0) }
        .task(id: container.dataVersion) {
            if model == nil { model = AccountsViewModel(container: container) }
            model?.load()
        }
    }

    private func list(_ model: AccountsViewModel) -> some View {
        List {
            if model.active.isEmpty {
                ContentUnavailableView("No Accounts", systemImage: "building.columns", description: Text("Add a cash, bank, savings or credit card account."))
            } else {
                Section {
                    ForEach(model.active) { item in
                        row(item)
                            .swipeActions {
                                Button("Archive", systemImage: "archivebox") { model.setArchived(true, accountId: item.id) }
                                    .tint(.orange)
                            }
                    }
                } footer: {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(model.total.formatted()).monospacedDigit()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
            if !model.archived.isEmpty {
                Section {
                    ForEach(model.archived) { item in
                        row(item)
                            .foregroundStyle(.secondary)
                            .swipeActions {
                                Button("Restore", systemImage: "arrow.uturn.backward") { model.setArchived(false, accountId: item.id) }
                                    .tint(Theme.accent)
                            }
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Archived accounts keep their history but can't be used for new transactions.")
                }
            }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.expense)
            }
        }
    }

    private func row(_ item: DashboardViewModel.AccountBalance) -> some View {
        Button {
            editing = item.account
        } label: {
            HStack {
                Label(item.account.name, systemImage: item.account.type.systemImage)
                Spacer()
                VStack(alignment: .trailing) {
                    BalanceText(balance: item.balance, accountType: item.account.type)
                    Text(item.account.type.displayName).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit account")
    }
}

struct AccountFormView: View {
    @State private var model: AccountFormViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, account: Account?) {
        _model = State(initialValue: AccountFormViewModel(container: container, editing: account))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name)
                    Picker("Type", selection: $model.type) {
                        ForEach(AccountType.allCases, id: \.self) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                    }
                    LabeledContent(model.balanceLabel) {
                        TextField("0", text: $model.openingBalanceText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                } footer: {
                    Text(model.type.isLiability
                         ? "Credit cards are tracked as money you owe. Card purchases are expenses; paying the card is a transfer from your bank account."
                         : "Balance in \(model.currency.rawValue) before the first transaction you record. Use a minus sign for an overdrawn account.")
                }
                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.expense) }
                }
            }
            .navigationTitle(model.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.save() { dismiss() } }
                }
            }
        }
    }
}
