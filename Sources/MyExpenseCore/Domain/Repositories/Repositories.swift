import Foundation

public enum RepositoryError: Error, Equatable, Sendable {
    case notFound
    case validation(TransactionValidationError)
    case storage(String)
}

/// Repositories isolate persistence (SwiftData now, Supabase sync later) from features.
/// They run on the main actor because SwiftData's main context does.
@MainActor
public protocol ProfileRepository: AnyObject {
    func current() throws -> Profile?
    func save(_ profile: Profile) throws
}

@MainActor
public protocol AccountRepository: AnyObject {
    func all(includeArchived: Bool) throws -> [Account]
    func save(_ account: Account) throws
    func setArchived(_ archived: Bool, id: UUID) throws
}

@MainActor
public protocol CategoryRepository: AnyObject {
    func all(includeArchived: Bool) throws -> [TransactionCategory]
    func save(_ category: TransactionCategory) throws
    func setArchived(_ archived: Bool, id: UUID) throws
    /// Inserts `DefaultCategories` only when no categories exist yet (FR-050).
    func seedDefaultsIfNeeded() throws
}

@MainActor
public protocol TransactionRepository: AnyObject {
    func transaction(id: UUID) throws -> Transaction?
    func fetch(_ query: TransactionQuery, page: PageRequest) throws -> [Transaction]
    /// Every non-deleted transaction; used to derive balances.
    func allActive() throws -> [Transaction]
    /// Validates, then inserts or updates. Updates bump `updatedAt`.
    func save(_ transaction: Transaction, validator: TransactionValidator) throws
    /// Soft delete (tombstone) so the delete can sync (ADR-006).
    func delete(id: UUID) throws
}

/// Receipt metadata. File bytes are stored separately by a `ReceiptFileStore`.
@MainActor
public protocol ReceiptRepository: AnyObject {
    func receipts(transactionId: UUID) throws -> [Receipt]
    func save(_ receipt: Receipt) throws
    func delete(id: UUID) throws
}

/// Stores receipt files in app-private storage (FR-092).
public protocol ReceiptFileStore: Sendable {
    /// Writes `data` and returns the stored file name.
    func write(_ data: Data, receiptId: UUID, contentType: ReceiptContentType) throws -> String
    func url(for fileName: String) -> URL
    func delete(fileName: String) throws
}
