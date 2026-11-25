import MyExpenseFeatures
import SwiftUI

/// One transaction in a list: category icon, title, subtitle and signed amount.
struct TransactionRowView: View {
    let row: TransactionPresenter.Row
    var showsDate = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: row.icon)
                .font(.body)
                .foregroundStyle(Color(hex: row.colorHex) ?? Theme.accent)
                .frame(width: 36, height: 36)
                .background((Color(hex: row.colorHex) ?? Theme.accent).opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).lineLimit(1)
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: 2) {
                TransactionAmountText(kind: row.transaction.kind, amount: row.transaction.amount)
                if showsDate {
                    Text(row.transaction.occurredAt, format: .dateTime.day().month(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
