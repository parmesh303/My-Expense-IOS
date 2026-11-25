# 05 — Phased Development Backlog

Each item references its SRS requirement IDs. Work stops for approval at every phase boundary (SRS §19).

## Phase 0 — Product & architecture ✅
- [x] Confirm the open decisions (see 01-architecture §1)
- [x] Architecture proposal and ADRs, user flows, schema, traceability matrix, backlog

## Phase 1 — Foundation ✅
- [x] `MyExpenseCore` Swift package: Money, domain models, repository protocols
- [x] TransactionValidator (FR-023/045/053/054), LedgerCalculator (FR-044/046/047/067), ReportingPeriod (FR-013/083)
- [x] Default categories (FR-050)
- [x] In-memory repositories for tests and previews
- [x] Unit test target (`swift test`)
- [x] iOS app skeleton: SwiftData SchemaV1 + migration plan, repositories, DI container, 5-tab navigation, design system, onboarding
- [x] XcodeGen `project.yml`, README, `.gitignore`, git repository
- [ ] Generate the Xcode project and run on a simulator (needs a Mac with Xcode 26)

## Phase 2 — Core finance ✅ (this delivery)
- [x] Add/Edit transaction with validation, refund toggle and locale-aware amounts (FR-020…025)
- [x] Transfers between accounts, same-account and cross-currency transfers blocked (FR-043…045)
- [x] Transaction list: search, filters, sort, day sections, paging, swipe delete with confirmation (FR-026…029, FR-032)
- [x] Transaction detail with edit/delete
- [x] Accounts: derived balances, total, create/edit, archive/restore, credit card "amount owed" (FR-040…042, FR-046)
- [x] Categories: create/rename/icon/colour, reorder, archive/restore with duplicate-name checks (FR-051…055)
- [x] Receipts: photo/PDF attach, 10 MB + type limits, max 5, Quick Look preview, remove (FR-090…096, local only)
- [x] `scripts/run.sh` + docs/06-run-on-iphone.md
- [ ] Camera capture for receipts (the photo picker covers the photo library; camera comes with OCR in Phase 8)
- [ ] Move remaining list filters into SwiftData predicates once real-device profiling shows a need (FR-032)
- [ ] First compile and run in Xcode (SwiftData files are not compiled yet)

## Phase 3 — Dashboard & budgets
- [ ] Dashboard cards, recent transactions, category donut (FR-010…016)
- [ ] BudgetCalculator + Budgets UI (FR-060…067)
- [ ] Budget threshold notifications, deduplicated (FR-065, §12)

## Phase 4 — Reports & export
- [ ] Reports with Swift Charts, comparisons, custom range (FR-080…088)
- [ ] CSV export (FR-100, FR-108), PDF report (FR-101), full JSON export (FR-102/103)

## Phase 5 — Cloud & sync
- [ ] Supabase project, migrations, RLS, receipts bucket (§8.4)
- [ ] Auth flows + Keychain (FR-003, SEC-001)
- [ ] Outbox, SyncService, backoff, conflicts, restore (FR-030/031/104/105/107)

## Phase 6 — Security & quality
- [ ] Face ID lock (FR-111, SEC-005), privacy screens, account deletion (FR-114…117)
- [ ] Accessibility audit, UI tests, performance checks

## Phase 7 — Release
- [ ] TestFlight, metadata, privacy labels, reviewer notes

## Phase 8 — Future
- [ ] Recurring automation, OCR, AI categorization (opt-in)
