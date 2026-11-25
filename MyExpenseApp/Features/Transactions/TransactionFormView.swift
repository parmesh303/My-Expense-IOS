import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Add/Edit transaction sheet (S5).
struct TransactionFormView: View {
    @State private var model: TransactionFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    init(container: AppContainer, editing transaction: Transaction? = nil) {
        _model = State(initialValue: TransactionFormViewModel(container: container, editing: transaction))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !model.hasAccounts {
                    Section {
                        Label("Create an account in Settings › Accounts before adding transactions.", systemImage: "exclamationmark.circle")
                    }
                }

                Section {
                    Picker("Type", selection: $model.entryType) {
                        ForEach(TransactionFormViewModel.EntryType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("form.type")

                    HStack {
                        Text(model.currency.rawValue)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $model.amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.monospacedDigit())
                            .focused($amountFocused)
                            .accessibilityLabel("Amount")
                            .accessibilityIdentifier("form.amount")
                    }

                    if model.entryType == .expense {
                        Toggle("This is a refund", isOn: $model.isRefund)
                    }
                } footer: {
                    if model.isRefund {
                        Text("Refunds add money back to the account and reduce spending in the chosen category. They are not counted as income.")
                    }
                }

                Section {
                    Picker(model.entryType == .transfer ? "From" : "Account", selection: $model.accountId) {
                        ForEach(model.accounts) { account in
                            Label(account.name, systemImage: account.type.systemImage).tag(Optional(account.id))
                        }
                    }
                    if model.entryType == .transfer {
                        Picker("To", selection: $model.destinationAccountId) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(model.accounts.filter { $0.id != model.accountId }) { account in
                                Label(account.name, systemImage: account.type.systemImage).tag(Optional(account.id))
                            }
                        }
                    } else {
                        Picker("Category", selection: $model.categoryId) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(model.availableCategories) { category in
                                Label(category.name, systemImage: category.icon).tag(Optional(category.id))
                            }
                        }
                        .accessibilityIdentifier("form.category")
                    }
                    DatePicker("Date", selection: $model.occurredAt)
                }

                Section {
                    if model.entryType != .transfer {
                        TextField(model.entryType == .income ? "Payer" : "Payee / merchant", text: $model.merchant)
                    }
                    TextField("Notes", text: $model.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let message = model.saveError {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Theme.expense)
                    }
                }
            }
            .navigationTitle(model.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save() { dismiss() }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("form.save")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message = model.validationMessage, !model.amountText.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, Theme.Spacing.s)
                }
            }
            .onAppear { if !model.isEditing { amountFocused = true } }
        }
    }
}

#if DEBUG
struct TransactionFormView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionFormView(container: .inMemory())
    }
}
#endif
