import MyExpenseFeatures
import OSLog
import SwiftUI

@main
struct MyExpenseApp: App {
    @State private var container: AppContainer?
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    private static let logger = Logger(subsystem: "MyExpense", category: "Launch")

    init() {
        // UI tests launch with a throwaway in-memory store.
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTestingInMemoryStore")
        do {
            _container = State(initialValue: try AppContainer.live(inMemory: inMemory))
        } catch {
            // Never log user data (SEC-007); the error type alone is enough to diagnose.
            Self.logger.error("Failed to open local store: \(String(describing: type(of: error)), privacy: .public)")
            _container = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .environment(container)
                } else {
                    ContentUnavailableView(
                        "Unable to Open Your Data",
                        systemImage: "exclamationmark.triangle",
                        description: Text("MyExpense could not open its on-device storage. Restart the app; if the problem continues, contact support.")
                    )
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .tint(Theme.accent)
        }
    }
}
