import MyExpenseFeatures
import SwiftUI

/// Chooses between startup error, onboarding and the main tab interface.
struct RootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        if let message = container.startupError {
            ContentUnavailableView("Unable to Load Data", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if container.profile == nil {
            OnboardingView(container: container)
        } else {
            MainTabView()
        }
    }
}

enum AppTab: Hashable {
    case home, transactions, budgets, reports, settings
}

/// Five-tab navigation (SRS §11.1).
struct MainTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: .home) {
                DashboardView()
            }
            Tab("Transactions", systemImage: "list.bullet.rectangle", value: .transactions) {
                TransactionsView()
            }
            Tab("Budgets", systemImage: "chart.pie", value: .budgets) {
                BudgetsView()
            }
            Tab("Reports", systemImage: "chart.bar.xaxis", value: .reports) {
                ReportsView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environment(AppContainer.inMemory())
    }
}
#endif
