import SwiftUI

/// Budget tracking arrives in Phase 3 (FR-060…FR-067).
struct BudgetsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Budgets",
                systemImage: "chart.pie",
                description: Text("Monthly and category budgets are coming in a future update.")
            )
            .navigationTitle("Budgets")
        }
    }
}
