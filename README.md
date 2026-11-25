# MyExpense — iOS Personal Expense Manager

Native SwiftUI app for recording income, expenses and transfers, with budgets, reports and optional cloud sync.
It implements the *MyExpense iOS SRS v1.0*.

**Current status: Phase 2 (core finance) complete.** See [docs/05-backlog.md](docs/05-backlog.md).

## Project layout

```
MyExpense/
├── Package.swift              # SwiftPM: MyExpenseCore + MyExpenseFeatures (+ tests)
├── Sources/
│   ├── MyExpenseCore/         # Domain models, money, ledger, validation, periods, repository protocols
│   └── MyExpenseFeatures/     # @Observable view models + AppContainer (DI)
├── Tests/                     # Swift Testing unit tests (run with `swift test`)
├── MyExpenseApp/              # iOS app target (SwiftUI views, SwiftData persistence)
│   ├── App/                   # @main, RootView, tab navigation, live container
│   ├── Core/Database/         # SwiftData SchemaV1 + migration plan
│   ├── Data/                  # SwiftData repositories + record mappers
│   ├── Features/              # Onboarding, Dashboard, Transactions, Budgets, Reports, Settings
│   ├── Shared/                # Design system and components
│   └── Resources/             # Info.plist, assets, privacy manifest
├── project.yml                # XcodeGen spec → MyExpense.xcodeproj
├── scripts/run.sh             # Build & launch on Simulator or iPhone
└── docs/                      # Architecture, flows, schema, traceability, backlog
```

All financial rules live in `MyExpenseCore`, which is UI-free and fully unit-tested. The app target stays thin.

## Requirements

* Swift 6.2+ toolchain (Command Line Tools are enough for `swift test`)
* To run the iOS app: Xcode 26+ with the iOS 26 SDK
* [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Common commands

```bash
# Run all unit tests (core rules + view models). No Xcode required.
swift test

# Generate the Xcode project (it is git-ignored; regenerate after adding files)
xcodegen generate
open MyExpense.xcodeproj

# Build + launch (requires Xcode); see docs/06-run-on-iphone.md
scripts/run.sh simulator
TEAM_ID=YOURTEAMID BUNDLE_ID=com.yourname.myexpense scripts/run.sh device
```

Before the first device build, set your team and change `bundleIdPrefix` / `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`.

## Key business rules

| Rule | Where |
|---|---|
| Money is `Int64` minor units + ISO currency; input rounded half-even | `Money.swift` (ADR-001) |
| Transfers are one ledger row and never count as income or expense | `LedgerCalculator` (ADR-002) |
| Credit cards are liabilities; card payment = transfer | ADR-003 |
| Refunds reduce spending and are not income | ADR-004 |
| Balances are derived from the opening balance plus ledger rows | ADR-005 |
| Deletes are soft (tombstones) for future sync | ADR-006 |

Full details are in [docs/01-architecture.md](docs/01-architecture.md).

## Privacy & security notes

* No analytics or third-party SDKs.
* Never log amounts, account names or other user data. Use `os.Logger` with `.private`, or log only types and identifiers.
* No secrets in the repo. Supabase configuration (Phase 5) will come from a git-ignored `Secrets.xcconfig` and contain only the anon key.
