# 04 — Requirement → Test Traceability Matrix

Status legend: ✅ implemented + tested · 🟡 partially implemented · ⬜ planned.
Unit tests live in `Tests/MyExpenseCoreTests` and `Tests/MyExpenseFeaturesTests`. UI and integration tests are added to the Xcode project in their phase.

| Req | Summary | Phase | Test(s) | Status |
|---|---|---|---|---|
| FR-001/002/005/006 | Onboarding, local-only choice, not-a-backup acknowledgement | 1 | `OnboardingViewModelTests.storageStep*`, `cloudModeCannotBeChosen*`; UI: `OnboardingUITests` | ✅ unit · ⬜ UI test (needs Xcode) |
| FR-004 | Display name & currency | 1 | `ProfileTests.validation`, `OnboardingViewModelTests.finish*` | ✅ |
| FR-010/011 | Period totals, balances, recent | 1 | `LedgerCalculatorTests.summaryTotals*`, `DashboardViewModelTests.totalsExcludeTransfers*` | ✅ |
| FR-013 | Change reporting period | 1 | `DashboardViewModelTests.periodNavigation` | ✅ |
| FR-014 | Dashboard empty state | 1 | `DashboardViewModelTests.emptyStateStillShowsOpeningBalances` | ✅ |
| FR-012/082 | Category spending | 3 | `LedgerCalculatorTests.categoryBreakdown*` | ✅ |
| FR-013/080/085 | Reporting periods / custom range | 3 | `ReportingPeriodTests.*` | ✅ |
| FR-015/016/087 | Totals from data, transfers excluded | 2 | `LedgerCalculatorTests.transfersExcludedFromTotals` | ✅ |
| FR-020/021 | Transaction kinds & fields | 1 | `TransactionValidatorTests.*` | ✅ |
| FR-023 | Reject zero/negative amounts | 1 | `TransactionValidatorTests.rejectsNonPositiveAmount` | ✅ |
| FR-026/027/028 | Search, filter, sort | 2 | `TransactionQueryTests.*` | ✅ |
| FR-022/024/025 | Add/edit, date, notes & payee | 2 | `TransactionFormViewModelTests.*` | ✅ |
| FR-023 (UI) | Form rejects 0/negative/invalid amounts | 2 | `TransactionFormViewModelTests.rejectsInvalidAmounts` | ✅ |
| FR-029 | Delete confirmation, soft delete | 2 | `TransactionListViewModelTests.deleteIsSoftAndUpdatesBalances`; confirmation dialog in UI | ✅ unit · ⬜ UI test |
| FR-031/074 | Idempotent retry | 5 | Integration: `SyncServiceTests.retryNoDuplicate` | ⬜ |
| FR-032 | Incremental loading | 2 | `InMemoryTransactionRepositoryTests.paging`, `TransactionListViewModelTests.pagingAndDaySections` | ✅ |
| FR-026/027/028 (UI) | List search/filters/sort | 2 | `TransactionListViewModelTests.*` | ✅ |
| FR-041/042 | Account create/edit/archive | 2 | `AccountViewModelTests.*`, `NameValidatorTests.*` | ✅ |
| FR-043/045 (UI) | Transfer form | 2 | `TransactionFormViewModelTests.transferToSameAccountIsRejected` | ✅ |
| FR-051/052 | Category create/rename/reorder/archive | 2 | `CategoryViewModelTests.*` | ✅ |
| FR-044 | Transfer moves balances only | 1 | `LedgerCalculatorTests.transferMovesBalances` | ✅ |
| FR-045 | Same-account transfer rejected | 1 | `TransactionValidatorTests.rejectsSameAccountTransfer` | ✅ |
| FR-046 | Credit-card rules | 1 | `LedgerCalculatorTests.creditCardPurchaseAndPayment` | ✅ |
| FR-047 | Derived balances, edit/delete recalc | 1 | `LedgerCalculatorTests.deletedTransactionsIgnored` | ✅ |
| FR-050 | Default categories | 1 | `DefaultCategoriesTests.*` | ✅ |
| FR-053 | Category/kind compatibility | 1 | `TransactionValidatorTests.rejectsIncompatibleCategory` | ✅ |
| FR-054 | Archived category retains history | 1 | `TransactionValidatorTests.archivedCategoryRejectedForNewButKeptForHistory` | ✅ |
| FR-062/063/066 | Budget usage | 3 | `BudgetCalculatorTests.*` | ⬜ |
| FR-065 | Thresholds 75/90/100, no duplicates | 3 | `BudgetCalculatorTests.thresholds` | ⬜ |
| FR-067 | Refunds reduce spending | 1 | `LedgerCalculatorTests.refundReducesSpending` | ✅ |
| FR-070…075 | Recurring rules | 8 | `RecurrenceSchedulerTests.*` | ⬜ |
| FR-083 | Previous-period comparison | 3 | `ReportingPeriodTests.previousPeriod` | ✅ |
| FR-090/093/095/096 | Receipts attach/view/remove, limits | 2 | `ReceiptValidatorTests.*`, `ReceiptsViewModelTests.*` | ✅ (local) |
| FR-092/094 | Cloud receipt storage & upload status | 5 | Integration | ⬜ |
| FR-100/108 | CSV export format | 4 | `CSVExporterTests.*` | ⬜ |
| FR-102 | Full JSON export | 4 | `FullExportTests.roundTrip` | ⬜ |
| FR-104/107 | Sync status/errors | 5 | Integration | ⬜ |
| FR-110 | Settings: name, currency, week start, theme | 1 | `SettingsViewModelTests.savesValidatedChanges` | ✅ |
| FR-111 | Biometric toggle | 6 | UI | ⬜ |
| SEC-001 | Keychain tokens | 5 | Integration: `KeychainStoreTests` | ⬜ |
| SEC-003/015 | RLS boundaries | 5 | pgTAP `rls_test.sql` | ⬜ |
| SEC-005/006 | Face ID lock | 6 | UI (manual on device) | ⬜ |
| SEC-007 | No sensitive logging | all | Code review checklist | 🟡 |
| §7.2 | Money precision & rounding | 1 | `MoneyTests.*` | ✅ |
