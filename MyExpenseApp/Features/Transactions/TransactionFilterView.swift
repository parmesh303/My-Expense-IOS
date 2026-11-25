import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Filter sheet: date range, type, account, category and amount range (FR-027).
struct TransactionFilterView: View {
    @Bindable var model: TransactionListViewModel
    @Environment(\.dismiss) private var dismiss

    private let kindOptions: [(TransactionKind, String)] = [
        (.expense, "Expenses"), (.income, "Income"), (.refund, "Refunds"), (.transfer, "Transfers"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Picker("Range", selection: $model.filter.dateOption) {
                        ForEach(TransactionFilter.DateOption.allCases) { Text($0.title).tag($0) }
                    }
                    if model.filter.dateOption == .custom {
                        DatePicker("From", selection: $model.filter.customStart, displayedComponents: .date)
                        DatePicker("To", selection: $model.filter.customEnd, in: model.filter.customStart..., displayedComponents: .date)
                    }
                }

                Section("Type") {
                    ForEach(kindOptions, id: \.0) { kind, title in
                        Toggle(title, isOn: binding(for: kind, in: \.kinds))
                    }
                }

                Section("Accounts") {
                    ForEach(model.accounts) { account in
                        Toggle(account.isArchived ? "\(account.name) (archived)" : account.name, isOn: binding(for: account.id, in: \.accountIds))
                    }
                }

                Section("Categories") {
                    ForEach(model.categories) { category in
                        Toggle(isOn: binding(for: category.id, in: \.categoryIds)) {
                            Label(category.isArchived ? "\(category.name) (archived)" : category.name, systemImage: category.icon)
                        }
                    }
                }

                Section {
                    TextField("Minimum", text: $model.filter.minAmountText)
                        .keyboardType(.decimalPad)
                    TextField("Maximum", text: $model.filter.maxAmountText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Amount")
                } footer: {
                    if let error = model.amountFilterError {
                        Text(error).foregroundStyle(Theme.expense)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { model.filter = TransactionFilter() }
                        .disabled(model.filter.activeCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func binding<Value: Hashable>(for value: Value, in keyPath: WritableKeyPath<TransactionFilter, Set<Value>>) -> Binding<Bool> {
        Binding(
            get: { model.filter[keyPath: keyPath].contains(value) },
            set: { isOn in
                if isOn { model.filter[keyPath: keyPath].insert(value) } else { model.filter[keyPath: keyPath].remove(value) }
            }
        )
    }
}
