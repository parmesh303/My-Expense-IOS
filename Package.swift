// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyExpenseCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MyExpenseCore", targets: ["MyExpenseCore"]),
        .library(name: "MyExpenseFeatures", targets: ["MyExpenseFeatures"]),
    ],
    targets: [
        // Domain models, financial rules and repository protocols. Foundation only.
        .target(name: "MyExpenseCore"),
        // UI-independent view models and the dependency container used by the iOS app.
        .target(name: "MyExpenseFeatures", dependencies: ["MyExpenseCore"]),
        .testTarget(name: "MyExpenseCoreTests", dependencies: ["MyExpenseCore"]),
        .testTarget(name: "MyExpenseFeaturesTests", dependencies: ["MyExpenseFeatures"]),
    ]
)
