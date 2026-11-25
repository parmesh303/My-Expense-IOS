import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Settings tab (FR-110, FR-113, FR-115). Security, sync, export and deletion are added in later phases.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        NavigationStack {
            SettingsForm(container: container)
                .navigationTitle("Settings")
        }
    }
}

private struct SettingsForm: View {
    @State private var model: SettingsViewModel
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    init(container: AppContainer) {
        _model = State(initialValue: SettingsViewModel(container: container))
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $model.displayName)
                    .textContentType(.name)
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
                if model.hasChanges {
                    Button("Save Changes") { model.save() }
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(Theme.expense)
                }
            }

            Section("Manage") {
                NavigationLink {
                    AccountsView()
                } label: {
                    Label("Accounts", systemImage: "building.columns")
                }
                NavigationLink {
                    CategoriesView()
                } label: {
                    Label("Categories", systemImage: "square.grid.2x2")
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section {
                Label {
                    Text(model.storageDescription)
                        .font(.callout)
                } icon: {
                    Image(systemName: "iphone")
                }
                if let url = AppInfo.privacyPolicyURL {
                    Link("Privacy Policy", destination: url)
                } else {
                    LabeledContent("Privacy Policy", value: "Not yet published")
                }
            } header: {
                Text("Data & Privacy")
            } footer: {
                Text("MyExpense does not use analytics or share your financial records.")
            }

            Section("About") {
                LabeledContent("Version", value: AppInfo.version)
            }
        }
    }
}

enum AppInfo {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "MyExpense"
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    /// Configured per build via the `MEPrivacyPolicyURL` Info.plist key.
    static var privacyPolicyURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MEPrivacyPolicyURL") as? String,
              let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(AppContainer.inMemory(profile: Profile(displayName: "Parmesh")))
    }
}
#endif
