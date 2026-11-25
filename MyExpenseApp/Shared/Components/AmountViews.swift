import MyExpenseCore
import SwiftUI

/// Formats a transaction amount with sign, colour and an accessibility label,
/// so direction is never conveyed by colour alone (SRS §11.3).
struct TransactionAmountText: View {
    let kind: TransactionKind
    let amount: Money

    var body: some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(color)
            .accessibilityLabel(accessibilityText)
    }

    private var formatted: String { amount.formatted() }

    private var text: String {
        switch kind {
        case .income, .refund: "+\(formatted)"
        case .expense: "−\(formatted)"
        case .transfer: formatted
        }
    }

    private var color: Color {
        switch kind {
        case .income, .refund: Theme.income
        case .expense: Theme.expense
        case .transfer: Theme.transfer
        }
    }

    private var accessibilityText: String {
        switch kind {
        case .income: "Income \(formatted)"
        case .refund: "Refund \(formatted)"
        case .expense: "Expense \(formatted)"
        case .transfer: "Transfer \(formatted)"
        }
    }
}

/// Shows an account balance. Credit card debt is shown as "Owed" (ADR-003).
struct BalanceText: View {
    let balance: Money
    let accountType: AccountType

    var body: some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(balance.minorUnits < 0 ? Theme.expense : .primary)
            .accessibilityLabel(text)
    }

    private var text: String {
        let magnitude = Money(minorUnits: abs(balance.minorUnits), currency: balance.currency).formatted()
        if balance.minorUnits < 0 {
            return accountType.isLiability ? "Owed \(magnitude)" : "−\(magnitude)"
        }
        return magnitude
    }
}

/// Labelled figure used on summary cards.
struct SummaryFigure: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
