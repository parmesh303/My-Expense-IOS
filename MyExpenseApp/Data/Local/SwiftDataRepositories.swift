import Foundation
import MyExpenseCore
import SwiftData

/// SwiftData-backed repositories. Each one holds the `ModelContainer` so it outlives the context.
@MainActor
final class SwiftDataProfileRepository: ProfileRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) { self.container = container }

    func current() throws -> Profile? {
        var descriptor = FetchDescriptor<ProfileRecord>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    func save(_ profile: Profile) throws {
        let id = profile.id
        var descriptor = FetchDescriptor<ProfileRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let record = try context.fetch(descriptor).first {
            record.apply(profile)
        } else {
            context.insert(ProfileRecord(profile))
        }
        try context.save()
    }
}

@MainActor
final class SwiftDataAccountRepository: AccountRepository {
    private let container: ModelContainer
    private let clock: @Sendable () -> Date
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, clock: @escaping @Sendable () -> Date) {
        self.container = container
        self.clock = clock
    }

    func all(includeArchived: Bool) throws -> [Account] {
        let descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
            .map { try $0.toDomain() }
            .filter { includeArchived || !$0.isArchived }
    }

    func save(_ account: Account) throws {
        if let record = try record(id: account.id) {
            record.apply(account, now: clock())
        } else {
            context.insert(AccountRecord(account))
        }
        try context.save()
    }

    func setArchived(_ archived: Bool, id: UUID) throws {
        guard let record = try record(id: id) else { throw RepositoryError.notFound }
        let now = clock()
        record.archivedAt = archived ? now : nil
        record.updatedAt = now
        record.version += 1
        try context.save()
    }

    private func record(id: UUID) throws -> AccountRecord? {
        var descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataCategoryRepository: CategoryRepository {
    private let container: ModelContainer
    private let clock: @Sendable () -> Date
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, clock: @escaping @Sendable () -> Date) {
        self.container = container
        self.clock = clock
    }

    func all(includeArchived: Bool) throws -> [TransactionCategory] {
        let descriptor = FetchDescriptor<CategoryRecord>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.kindRaw), SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
            .map { try $0.toDomain() }
            .filter { includeArchived || !$0.isArchived }
    }

    func save(_ category: TransactionCategory) throws {
        if let record = try record(id: category.id) {
            record.apply(category, now: clock())
        } else {
            context.insert(CategoryRecord(category, now: clock()))
        }
        try context.save()
    }

    func setArchived(_ archived: Bool, id: UUID) throws {
        guard let record = try record(id: id) else { throw RepositoryError.notFound }
        let now = clock()
        record.archivedAt = archived ? now : nil
        record.updatedAt = now
        record.version += 1
        try context.save()
    }

    func seedDefaultsIfNeeded() throws {
        guard try context.fetchCount(FetchDescriptor<CategoryRecord>()) == 0 else { return }
        let now = clock()
        for category in DefaultCategories.make() {
            context.insert(CategoryRecord(category, now: now))
        }
        try context.save()
    }

    private func record(id: UUID) throws -> CategoryRecord? {
        var descriptor = FetchDescriptor<CategoryRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    private let container: ModelContainer
    private let clock: @Sendable () -> Date
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, clock: @escaping @Sendable () -> Date) {
        self.container = container
        self.clock = clock
    }

    func transaction(id: UUID) throws -> Transaction? {
        try record(id: id)?.toDomain()
    }

    func fetch(_ query: TransactionQuery, page: PageRequest) throws -> [Transaction] {
        // Deleted rows and the date range are filtered in the store; the remaining criteria use the
        // shared `TransactionQuery` rules so search/filter behaviour matches the unit-tested logic.
        // Phase 2 will push more filters into the predicate for large histories (FR-032).
        let start = query.dateRange?.start ?? .distantPast
        let end = query.dateRange?.end ?? .distantFuture
        let descriptor: FetchDescriptor<TransactionRecord>
        if query.includeDeleted {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end })
        } else {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.deletedAt == nil && $0.occurredAt >= start && $0.occurredAt < end })
        }
        let categoryNames = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CategoryRecord>()).map { ($0.id, $0.name) })
        let accountNames = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<AccountRecord>()).map { ($0.id, $0.name) })
        let matching = try context.fetch(descriptor)
            .map { try $0.toDomain() }
            .filter { query.matches($0, categoryNames: categoryNames, accountNames: accountNames) }
            .sorted(by: query.areInIncreasingOrder)
        guard page.offset < matching.count else { return [] }
        return Array(matching[page.offset..<min(page.offset + page.limit, matching.count)])
    }

    func allActive() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.deletedAt == nil }))
            .map { try $0.toDomain() }
    }

    func save(_ transaction: Transaction, validator: TransactionValidator) throws {
        let existing = try record(id: transaction.id)
        let original = try existing?.toDomain()
        do {
            try validator.validate(transaction, original: original)
        } catch {
            throw RepositoryError.validation(error)
        }
        if let existing {
            existing.apply(transaction, now: clock())
        } else {
            context.insert(TransactionRecord(transaction))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try record(id: id) else { throw RepositoryError.notFound }
        let now = clock()
        record.deletedAt = now
        record.updatedAt = now
        record.version += 1
        try context.save()
    }

    private func record(id: UUID) throws -> TransactionRecord? {
        var descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataReceiptRepository: ReceiptRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) { self.container = container }

    func receipts(transactionId: UUID) throws -> [Receipt] {
        let descriptor = FetchDescriptor<ReceiptRecord>(
            predicate: #Predicate { $0.transactionId == transactionId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { try $0.toDomain() }
    }

    func save(_ receipt: Receipt) throws {
        let id = receipt.id
        var descriptor = FetchDescriptor<ReceiptRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.uploadStateRaw = receipt.uploadState.rawValue
        } else {
            context.insert(ReceiptRecord(receipt))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<ReceiptRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { throw RepositoryError.notFound }
        context.delete(record)
        try context.save()
    }
}
