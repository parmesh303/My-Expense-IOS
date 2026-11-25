# 01 — Architecture Proposal

Status: **Proposed (Phase 0)** · SRS v1.0 · Last updated 2026-11-25

## 1. Confirmed decisions (SRS §18)

| Decision | Choice |
|---|---|
| App name | MyExpense (working title) |
| Platform | iPhone only |
| Minimum OS | **iOS 26** |
| Default currency | INR; single currency in MVP, schema stores a currency code on every amount |
| Storage | **Local-first** (SwiftData). Supabase cloud sync added in Phase 5 |
| Login | Optional. Local use needs no account; cloud sync needs a Supabase account |
| Accounts | Multiple accounts: cash, bank, savings, credit card, wallet |
| Credit cards | **Liability model** (ADR-003) |
| Receipts | **Included in MVP** (basic image/PDF attachment) |
| AI | Future phase, disabled by default |
| Build tooling | Sources + XcodeGen `project.yml`. The core logic is built and tested with SwiftPM (`swift test`) |

## 2. Layered architecture

```
┌──────────────────────────── iOS App target (MyExpense/) ────────────────────────────┐
│ Features/*  SwiftUI Views  ──►  @Observable ViewModels                              │
│ Shared/DesignSystem, Components                                                     │
│ App/  MyExpenseApp, AppContainer (DI), RootView / tab routing                       │
│ Data/Local  SwiftData @Model records + Swift*Repository (implements Domain protocols)│
│ Data/Mappers record ⇄ domain                                                        │
│ Services/   Authentication, Sync, Export, Receipt, Notification, BiometricLock      │
└───────────────────────────────────────┬─────────────────────────────────────────────┘
                                        │ depends on
┌───────────────────────── MyExpenseCore (Swift package, no UI) ──────────────────────┐
│ Domain/Models   Money, Account, Category, Transaction, Budget, RecurringRule, ...   │
│ Domain/Repositories  protocols (AccountRepository, TransactionRepository, ...)      │
│ Domain/UseCases  TransactionValidator, LedgerCalculator, ReportingPeriod,           │
│                  BudgetCalculator, CSVExporter, RecurrenceScheduler (later phases)  │
│ Testing/  InMemory repositories (used by unit tests and SwiftUI previews)           │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

* **MVVM + Repository.** Views only render and send intents. ViewModels call use cases and repositories. Repositories hide SwiftData now and Supabase later.
* **The core is platform-independent.** It uses Foundation only, so every financial rule runs under `swift test` on any Mac, without a simulator.
* **Dependency injection.** `AppContainer` builds concrete repositories and services once and passes them through SwiftUI's `Environment`. Tests and previews inject the in-memory versions.
* **Concurrency.** Swift 6 strict concurrency. Domain types are `Sendable` value types. Persistence runs on `@MainActor`, or on a `ModelActor` for heavy report queries (SRS §10.1).
* **No LLM dependency** (SRS §5.1).

## 3. Architecture Decision Records

### ADR-001 Money representation
Amounts are stored as **`Int64` minor units** (paise) together with an ISO-4217 `currencyCode`.
* Why: exact arithmetic, no floating-point error, and the same representation works in SwiftData (`Int64`) and Postgres (`bigint`).
* Rounding: input text is parsed with `Decimal` and rounded half-even to the currency's minor-unit digits (INR = 2, JPY = 0).
* Multi-currency transfers are **blocked in MVP**. A transfer's two accounts must share a currency (SRS §7.3).

### ADR-002 One ledger table, transfers included
The SRS lists a separate `transfers` entity. We store every movement in **one `transactions` table** with `kind ∈ {income, expense, refund, transfer}`. A transfer uses `account_id` (source) and `counterpart_account_id` (destination).
* Why: one row is one atomic ledger event, so the two sides of a transfer can't drift apart. It also gives one sync unit and one tombstone, and avoids duplicate balance updates (FR-047).
* A DB `CHECK` enforces: transfer ⇒ counterpart is set, differs from the source, and category is null. Non-transfer ⇒ counterpart is null.

### ADR-003 Credit cards are liabilities
* An account balance is a **signed amount**: `opening + income + refunds − expenses − transfersOut + transfersIn`.
* For a credit card, a negative balance means **amount owed**. The UI shows it as "Owed ₹X". The opening balance is entered as the amount owed and stored negative.
* A card **purchase** is an `expense` on the card account. It is counted as spending once, at purchase time.
* A card **payment** is a `transfer` from bank to card. It is never an expense, so nothing is double-counted (FR-046).

### ADR-004 Refunds
* A refund is its own kind, `refund`, linked to an **expense category**.
* It increases the account balance and **reduces** expense totals and budget usage for its category and period (FR-067).
* It is **not** income. "Net spending" = expenses − refunds.

### ADR-005 Balances are derived, never stored
`LedgerCalculator` computes balances from the opening balance plus non-deleted ledger rows (SRS §7.3 preferred approach). Cached aggregates are added only if profiling shows a need, and must be checked against the derived value in tests.

### ADR-006 Deletion and sync tombstones
User-owned rows are soft-deleted with `deletedAt`, so deletes can propagate through sync. Accounts and categories are **archived** (`archivedAt`), never deleted, once history references them (FR-054).

### ADR-007 Sync (Phase 5)
* A durable **outbox** table in SwiftData stores: entityId, entityType, operation, localVersion, retryCount, lastErrorCategory, createdAt.
* Pushes use client-generated UUIDs and `upsert ... on conflict (id)`, so retries are **idempotent** (FR-031).
* Conflicts use an integer `version` per row. The server rejects stale writes (`version` mismatch), and the client keeps the losing revision for user review. Data is never overwritten silently (§8.3).
* Backoff: exponential, 2^n seconds with jitter, capped at 15 minutes. Permanent errors (4xx validation or auth) stop retrying and are shown to the user.

### ADR-008 Security
* Supabase **anon key only** in the app, provided through a git-ignored `Secrets.xcconfig`.
* RLS on every table. Tokens are stored in the Keychain.
* Biometric lock uses LocalAuthentication. It is an app-access gate, not authorization (SEC-006).
* Logging uses `os.Logger` with `.private` interpolation for any user data (SEC-007).
* No third-party SDKs except `supabase-swift`, which is added in Phase 5 with a justification.

### ADR-009 Naming and module boundaries
* The domain category type is called `TransactionCategory`, because Objective-C's `Category` typedef is visible in Apple-platform modules.
* SwiftUI also declares `Transaction`. The app target declares `typealias Transaction = MyExpenseCore.Transaction` so the domain type wins.
* View models live in the `MyExpenseFeatures` package target, so `swift test` can run them without a simulator.

## 4. Dependencies

| Dependency | Phase | Justification |
|---|---|---|
| None (Apple SDKs only) | 0–4, 6 | SwiftUI, SwiftData, Swift Charts, LocalAuthentication, UserNotifications, PDFKit |
| `supabase-swift` | 5 | Official client for Supabase Auth, Postgres, and Storage. Avoids hand-rolling auth token refresh |
| XcodeGen (dev tool, not shipped) | 1 | Generates `.xcodeproj` from `project.yml`, so project files stay reviewable in git |
