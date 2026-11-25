import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// First-run flow: welcome → storage choice → preferences → first account (FR-001…FR-006).
struct OnboardingView: View {
    @State private var model: OnboardingViewModel

    init(container: AppContainer) {
        _model = State(initialValue: OnboardingViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Form {
                switch model.step {
                case .welcome: welcome
                case .storage: storage
                case .preferences: preferences
                case .firstAccount: firstAccount
                }

                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Theme.expense)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                if model.step != .welcome {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { model.back() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: primaryAction) {
                    Text(model.isLastStep ? "Get Started" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canContinue)
                .padding()
                .accessibilityIdentifier("onboarding.primary")
            }
            .animation(.default, value: model.step)
        }
    }

    private var title: String {
        switch model.step {
        case .welcome: "Welcome"
        case .storage: "Your Data"
        case .preferences: "Preferences"
        case .firstAccount: "First Account"
        }
    }

    private func primaryAction() {
        if model.isLastStep {
            model.finish()
        } else {
            model.next()
        }
    }

    // MARK: Steps

    private var welcome: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Image(systemName: "indianrupeesign.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(AppInfo.displayName)
                    .font(.largeTitle.bold())
                Text("Record income and expenses, manage accounts and budgets, and understand where your money goes.")
                Text("MyExpense is a record-keeping tool. It does not connect to your bank, move money or verify balances.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    @ViewBuilder
    private var storage: some View {
        Section {
            Button {
                model.storageMode = .localOnly
            } label: {
                choiceRow(
                    title: "Keep data on this iPhone",
                    detail: "No account needed. Works offline.",
                    systemImage: "iphone",
                    selected: model.storageMode == .localOnly
                )
            }
            .buttonStyle(.plain)

            choiceRow(
                title: "Sync with a cloud account",
                detail: "Coming in a future update.",
                systemImage: "icloud",
                selected: false
            )
            .foregroundStyle(.tertiary)
            .accessibilityHint("Not available yet")
        } header: {
            Text("Where should your records be stored?")
        }

        Section {
            Toggle(isOn: $model.acknowledgedLocalOnlyRisk) {
                Text("I understand that data stored only on this iPhone is **not backed up** and cannot be recovered if the device is lost or reset, unless I export it.")
                    .font(.callout)
            }
            .accessibilityIdentifier("onboarding.acknowledgeRisk")
        }
    }

    private var preferences: some View {
        Section {
            TextField("Your name", text: $model.displayName)
                .textContentType(.name)
                .accessibilityIdentifier("onboarding.name")
            Picker("Currency", selection: $model.currency) {
                ForEach(OnboardingViewModel.supportedCurrencies, id: \.self) { code in
                    Text("\(code.rawValue) – \(code.localizedName)").tag(code)
                }
            }
            Picker("Week starts on", selection: $model.firstWeekday) {
                ForEach(WeekdayOptions.all, id: \.0) { weekday in
                    Text(weekday.1).tag(weekday.0)
                }
            }
        } footer: {
            Text("You can change these later in Settings.")
        }
    }

    @ViewBuilder
    private var firstAccount: some View {
        Section {
            Toggle("Create my first account", isOn: $model.createFirstAccount)
        }
        if model.createFirstAccount {
            Section {
                TextField("Account name", text: $model.accountName)
                Picker("Type", selection: $model.accountType) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                LabeledContent(model.accountType.isLiability ? "Amount owed" : "Opening balance") {
                    TextField("0", text: $model.openingBalanceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                }
            } footer: {
                Text(model.accountType.isLiability
                     ? "Enter how much you currently owe on this card."
                     : "Enter the current balance in \(model.currency.rawValue).")
            }
        }
    }

    private func choiceRow(title: String, detail: String, systemImage: String, selected: Bool) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Theme.accent : .secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(container: .inMemory())
    }
}
#endif
