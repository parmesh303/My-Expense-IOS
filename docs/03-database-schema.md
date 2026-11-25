# 03 — Database Schema & Migration Plan

Conventions (SRS §7.2):
* UUID primary keys are generated on the client, so they stay stable across devices.
* Money is `amount_minor bigint` + `currency_code char(3)` (ADR-001).
* Timestamps are UTC instants (`timestamptz` / `Date`). `occurred_tz` keeps the IANA zone of the transaction for reporting.
* Every user-owned row has `user_id`, `created_at`, `updated_at`, `version`, and `deleted_at` (tombstone).

## 1. Local schema — SwiftData `SchemaV1` (Phase 1)

| Model | Fields |
|---|---|
| `ProfileRecord` | id, displayName, preferredCurrency, firstWeekday, storageMode(local/cloud), createdAt, updatedAt |
| `AccountRecord` | id, name, typeRaw, currencyCode, openingBalanceMinor, sortOrder, archivedAt, createdAt, updatedAt, version, deletedAt |
| `CategoryRecord` | id, name, kindRaw(income/expense), icon, colorHex?, isSystem, sortOrder, archivedAt, createdAt, updatedAt, version, deletedAt |
| `TransactionRecord` | id, kindRaw, amountMinor, currencyCode, occurredAt, occurredTimeZone, accountId, counterpartAccountId?, categoryId?, merchant?, notes?, createdAt, updatedAt, version, deletedAt |
| `BudgetRecord` (Ph 3) | id, categoryId?, amountMinor, currencyCode, periodRaw, startDate, endDate?, thresholds, isPaused, createdAt, updatedAt, version, deletedAt |
| `RecurringRuleRecord` (Ph 8) | id, kindRaw, amountMinor, currencyCode, accountId, categoryId?, frequencyRaw, startDate, nextDueAt, endAt?, isActive, … |
| `ReceiptRecord` (V1) | id, transactionId, fileName, contentTypeRaw, fileSize, uploadStateRaw, storagePath?, createdAt. Files live in `Application Support/Receipts` with complete file protection |
| `OutboxEntryRecord` (Ph 5) | id, entityType, entityId, operation, localVersion, retryCount, lastErrorCategory?, nextAttemptAt, createdAt |

Foreign keys are stored as UUID columns, not SwiftData relationships. This keeps records one-to-one with the cloud rows, makes sync mapping trivial, and avoids cascade surprises. Indexes (`#Index`): `TransactionRecord(occurredAt)`, `(accountId)`, `(categoryId)`, `(kindRaw)`.

### Local migrations
* Every change ships as a new `VersionedSchema` (`SchemaV2`, …) plus a stage in `MyExpenseMigrationPlan`.
* Lightweight stages handle additive optional fields. Custom stages handle renames and backfills.
* A migration test opens a V(n-1) store fixture and checks that row counts and balances are unchanged (SRS §10.2).

## 2. Cloud schema — Supabase Postgres (Phase 5)

Migrations live in `supabase/migrations/NNNN_description.sql` and are applied with `supabase db push`.

```sql
-- 0001_core.sql (draft)
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null,
  preferred_currency char(3) not null default 'INR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table accounts (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (length(name) between 1 and 60),
  account_type text not null check (account_type in ('cash','bank','savings','credit_card','wallet')),
  currency_code char(3) not null,
  opening_balance_minor bigint not null default 0,
  sort_order int not null default 0,
  archived_at timestamptz,
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table categories (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  transaction_type text not null check (transaction_type in ('income','expense')),
  icon text not null, color text, is_system boolean not null default false,
  sort_order int not null default 0, archived_at timestamptz,
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table transactions (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  kind text not null check (kind in ('income','expense','refund','transfer')),
  amount_minor bigint not null check (amount_minor > 0),
  currency_code char(3) not null,
  occurred_at timestamptz not null,
  occurred_tz text not null,
  account_id uuid not null,
  counterpart_account_id uuid,
  category_id uuid,
  merchant text, notes text,
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  -- composite FKs guarantee related rows belong to the same user (SRS §8.4)
  foreign key (account_id, user_id) references accounts (id, user_id),
  foreign key (counterpart_account_id, user_id) references accounts (id, user_id),
  foreign key (category_id, user_id) references categories (id, user_id),
  check ((kind = 'transfer') = (counterpart_account_id is not null)),
  check (kind <> 'transfer' or (category_id is null and counterpart_account_id <> account_id))
);
create index on transactions (user_id, occurred_at desc);
create index on transactions (user_id, account_id);
create index on transactions (user_id, category_id);

-- budgets, recurring_rules, receipts, savings_goals follow the same pattern.
```

### RLS (every table)
```sql
alter table transactions enable row level security;
create policy "own rows select" on transactions for select using (user_id = auth.uid());
create policy "own rows insert" on transactions for insert with check (user_id = auth.uid());
create policy "own rows update" on transactions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows delete" on transactions for delete using (user_id = auth.uid());
```
* Receipts go in a private bucket `receipts`, with object path `{user_id}/{transaction_id}/{receipt_id}`. A storage policy checks that `(storage.foldername(name))[1] = auth.uid()::text`.
* A `version` trigger rejects updates where `new.version <> old.version + 1`, which surfaces conflicts (ADR-007).
* A pgTAP test suite tries cross-user reads and writes, which must all fail (SEC-015).

## 3. Migration roadmap

| Version | Phase | Change |
|---|---|---|
| Local V1 | 1–2 | Profile, Account, Category, Transaction, Receipt. Unreleased, so it may change until the first TestFlight build, then it is frozen |
| Local V2 | 3 | + Budget (additive, lightweight) |
| Local V3 | 5 | + OutboxEntry, sync fields (additive) |
| Local V4 | 8 | + RecurringRule |
| Cloud 0001–0003 | 5 | core tables + RLS, receipts bucket + policies, version trigger |
