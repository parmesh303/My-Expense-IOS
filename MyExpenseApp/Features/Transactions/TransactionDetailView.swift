import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Transaction detail (S6) with receipts (S11).
struct TransactionDetailView: View {
    let container: AppContainer
    @State private var model: TransactionDetailViewModel
    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, transactionId: UUID) {
        self.container = container
        _model = State(initialValue: TransactionDetailViewModel(container: container, transactionId: transactionId))
    }

    var body: some View {
        Group {
            if let transaction = model.transaction {
                details(transaction)
            } else if let error = model.errorMessage {
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ContentUnavailableView("Transaction Not Found", systemImage: "questionmark.folder", description: Text("It may have been deleted."))
            }
        }
        .navigationTitle(model.row?.title ?? "Transaction")
        .task(id: container.dataVersion) { model.load() }
    }

    private func details(_ transaction: Transaction) -> some View {
        List {
            Section {
                HStack {
                    Text(kindTitle(transaction.kind))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TransactionAmountText(kind: transaction.kind, amount: transaction.amount)
                        .font(.title2.bold())
                }
                LabeledContent("Date", value: transaction.occurredAt.formatted(date: .abbreviated, time: .shortened))
                if let destination = model.destinationName {
                    LabeledContent("From", value: model.accountName)
                    LabeledContent("To", value: destination)
                } else {
                    LabeledContent("Account", value: model.accountName)
                    LabeledContent("Category", value: model.categoryName)
                }
                if let merchant = transaction.merchant {
                    LabeledContent(transaction.kind == .income ? "Payer" : "Payee", value: merchant)
                }
                if let notes = transaction.notes {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Notes").foregroundStyle(.secondary).font(.caption)
                        Text(notes)
                    }
                }
            }

            ReceiptsSection(container: container, transactionId: transaction.id)

            Section {
                Button("Delete Transaction", role: .destructive) { confirmingDelete = true }
            } footer: {
                Text("Added \(transaction.createdAt.formatted(date: .abbreviated, time: .shortened)). Stored on this iPhone only.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            TransactionFormView(container: container, editing: transaction)
        }
        .confirmationDialog("Delete this transaction?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if model.delete() { dismiss() }
            }
        } message: {
            Text("Account balances and reports will be updated.")
        }
    }

    private func kindTitle(_ kind: TransactionKind) -> String {
        switch kind {
        case .income: "Income"
        case .expense: "Expense"
        case .refund: "Refund"
        case .transfer: "Transfer"
        }
    }
}
