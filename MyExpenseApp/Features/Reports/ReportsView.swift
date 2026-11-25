import SwiftUI

/// Reports and charts arrive in Phase 4 (FR-080…FR-088).
struct ReportsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Reports",
                systemImage: "chart.bar.xaxis",
                description: Text("Spending trends and comparisons are coming in a future update.")
            )
            .navigationTitle("Reports")
        }
    }
}
