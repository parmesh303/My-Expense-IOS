import Foundation

/// In-memory repositories for unit tests and SwiftUI previews. Never used for production data.
@MainActor
public final class InMemoryProfileRepository: ProfileRepository {
    private var profile: Profile?
    public init(profile: Profile? = nil) { self.profile = profile }
    public func current() throws -> Profile? { profile }
    public func save(_ profile: Profile) throws { self.profile = profile }
}

@MainActor
public final class InMemoryAccountRepository: AccountRepository {
    private var storage: [UUID: Account]
    private let clock: @Sendable () -> Date

    public init(accounts: [Account] = [], clock: @escaping @Sendable () -> Date = { .now }) {
        storage = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.clock = clock
    }

    public func all(includeArchived: Bool) throws -> [Account] {
        storage.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    public func save(_ account: Account) throws {
        var account = account
        if storage[account.id] != nil { account.updatedAt = clock() }
        storage[account.id] = account
    }

    public func setArchived(_ archived: Bool, id: UUID) throws {
        guard var account = storage[id] else { throw RepositoryError.notFound }
        account.archivedAt = archived ? clock() : nil
        account.updatedAt = clock()
        storage[id] = account
    }
}

@MainActor
public final class InMemoryCategoryRepository: CategoryRepository {
    private var storage: [UUID: TransactionCategory]
    private let clock: @Sendable () -> Date

    public init(categories: [TransactionCategory] = [], clock: @escaping @Sendable () -> Date = { .now }) {
        storage = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.clock = clock
    }

    public func all(includeArchived: Bool) throws -> [TransactionCategory] {
        storage.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { ($0.kind.rawValue, $0.sortOrder, $0.name) < ($1.kind.rawValue, $1.sortOrder, $1.name) }
    }

    public func save(_ category: TransactionCategory) throws { storage[category.id] = category }

    public func setArchived(_ archived: Bool, id: UUID) throws {
        guard var category = storage[id] else { throw RepositoryError.notFound }
        category.archivedAt = archived ? clock() : nil
        storage[id] = category
    }

    public func seedDefaultsIfNeeded() throws {
        guard storage.isEmpty else { return }
        for category in DefaultCategories.make() { storage[category.id] = category }
    }
}

@MainActor
public final class InMemoryTransactionRepository: TransactionRepository {
    private var storage: [UUID: Transaction]
    private let clock: @Sendable () -> Date

    public init(transactions: [Transaction] = [], clock: @escaping @Sendable () -> Date = { .now }) {
        storage = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        self.clock = clock
    }

    public func transaction(id: UUID) throws -> Transaction? { storage[id] }

    public func fetch(_ query: TransactionQuery, page: PageRequest) throws -> [Transaction] {
        let sorted = storage.values
            .filter { query.matches($0) }
            .sorted(by: query.areInIncreasingOrder)
        guard page.offset < sorted.count else { return [] }
        return Array(sorted[page.offset..<min(page.offset + page.limit, sorted.count)])
    }

    public func allActive() throws -> [Transaction] {
        storage.values.filter { !$0.isDeleted }
    }

    public func save(_ transaction: Transaction, validator: TransactionValidator) throws {
        let original = storage[transaction.id]
        do {
            try validator.validate(transaction, original: original)
        } catch {
            throw RepositoryError.validation(error)
        }
        var transaction = transaction
        if let original {
            transaction.createdAt = original.createdAt
            transaction.updatedAt = clock()
        }
        storage[transaction.id] = transaction
    }

    public func delete(id: UUID) throws {
        guard var transaction = storage[id] else { throw RepositoryError.notFound }
        transaction.deletedAt = clock()
        transaction.updatedAt = clock()
        storage[id] = transaction
    }
}

@MainActor
public final class InMemoryReceiptRepository: ReceiptRepository {
    private var storage: [UUID: Receipt] = [:]
    /// Set to make the next `save` fail, for testing rollback paths.
    public var failNextSave = false

    public init() {}

    public func receipts(transactionId: UUID) throws -> [Receipt] {
        storage.values.filter { $0.transactionId == transactionId }.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ receipt: Receipt) throws {
        if failNextSave {
            failNextSave = false
            throw RepositoryError.storage("Simulated failure")
        }
        storage[receipt.id] = receipt
    }

    public func delete(id: UUID) throws {
        guard storage.removeValue(forKey: id) != nil else { throw RepositoryError.notFound }
    }
}
