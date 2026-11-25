# 02 — Screen-by-Screen User Flow

## Navigation map

```
Launch
 ├─ (biometric lock enabled?) → LockScreen ──success──┐
 ├─ (first run?) → Onboarding ─────────────────────────┤
 └──────────────────────────────────────────────────────▼
                        TabView
   ┌──────────┬──────────────┬──────────┬──────────┬──────────┐
   │  Home    │ Transactions │ Budgets  │ Reports  │ Settings │
   └──────────┴──────────────┴──────────┴──────────┴──────────┘
   Global "+" (Home & Transactions) → Add/Edit Transaction sheet
```

## Screens

### S1 Onboarding (FR-001…006)
1. **Welcome**: what the app does and does not do (no bank connections, no payments).
2. **Storage choice**: "Keep data on this iPhone" or "Sync with a cloud account (coming soon / sign in)". Warns that on-device data is **not a backup** and is lost with the device unless exported (FR-005, FR-106).
3. **Preferences**: display name, currency (default INR), first day of week.
4. **First account**: create one account, prefilled as Cash with opening balance ₹0. Can be skipped.
→ Writes the profile, seeds default categories, and opens Home.

### S2 Sign in / Sign up (Phase 5, FR-003)
Email + password, magic link, forgot password. Reached from Onboarding step 2 or Settings › Cloud Sync.

### S3 Home / Dashboard (FR-010…016)
* Period selector: This month (default), week, year, custom.
* Cards: Income, Expenses (net of refunds), Net cash flow. Transfers are never included.
* Account balances. Credit cards show "Owed".
* Category spending (top 5) with a donut chart.
* Recent 10 transactions → Transaction detail.
* Empty state: "No transactions yet" plus an **Add transaction** button.

### S4 Transaction list (FR-026…032)
* Search bar (merchant, notes, category name, amount).
* Filter sheet: date range, kind, account, category, amount min/max.
* Sort: date ↓/↑, amount ↓/↑.
* Rows grouped by day, loaded incrementally (pages of 50).
* Swipe actions: Edit, Delete (with confirmation dialog).
* Sync badge on rows that are pending cloud sync (Phase 5, FR-030).

### S5 Add / Edit transaction (FR-020…025, FR-043…045, FR-053)
* Segmented control: Expense | Income | Transfer. Expense has a "Refund" toggle.
* Amount field with a numeric keypad, focused on open.
* Account (From/To for transfers) and Category (filtered by kind).
* Date/time (default now), Merchant/Payee, Notes.
* Receipt: Add photo / PDF (asks for permission only when tapped).
* Save stays disabled with inline errors until the form is valid: amount > 0, required fields set, transfer accounts differ and share a currency.

### S6 Transaction detail
All fields, the receipt thumbnail (→ Receipt viewer), and Edit / Delete.

### S7 Accounts (Settings › Accounts, and Home › Balances) (FR-040…047)
List with derived balances, an "Archived" section, Add/Edit sheet (name, type, currency, opening balance), and an Archive action.

### S8 Categories (Settings › Categories) (FR-050…055)
Expense and Income segments. Drag to reorder, rename, choose icon/color, archive. System categories can be renamed or archived but not deleted.

### S9 Budgets (FR-060…067)
Budget list with progress bars showing used / remaining / % used, coloured and labelled at 75/90/100%. Add/Edit sheet: total or per-category, amount, period (monthly/weekly/yearly), thresholds. Pause, delete with confirmation.

### S10 Reports (FR-080…088)
Period picker (day/week/month/year/custom), account filter, income-vs-expense bar chart, category breakdown, net cash-flow trend line, and "vs previous period" deltas.

### S11 Receipt viewer (FR-090…096)
Full-screen image/PDF, Share, Remove (with confirmation), and upload status (Phase 5).

### S12 Settings (FR-110…117)
Profile, Currency, Appearance (System/Light/Dark), First day of week, Notifications, Face ID lock, Accounts, Categories, Cloud Sync (status and last synced time), Export, "What is stored where", Privacy Policy, Delete local data / Delete account.

### S13 Export (FR-100…108)
Choose format (CSV transactions, full JSON export, PDF report) and date range. States whether receipts are included. Opens the share sheet.

### S14 Account deletion (FR-114, FR-116, FR-117)
Explains the consequences, offers "Export first", requires typing DELETE to confirm, deletes cloud data, and signs out.
