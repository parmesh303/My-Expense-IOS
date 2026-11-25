import Foundation
import SwiftData

/// Local schema version 1 (see docs/03-database-schema.md).
/// V1 is still unreleased, so it may change freely; freeze it at the first TestFlight build
/// and add `SchemaV2` + a migration stage for every later change.
/// Foreign keys are plain UUID columns so records map 1:1 to cloud rows (Phase 5).
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, AccountRecord.self, CategoryRecord.self, TransactionRecord.self, ReceiptRecord.self]
    }

    @Model
    final class ProfileRecord {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var preferredCurrency: String
        var firstWeekday: Int
        var storageMode: String
        var createdAt: Date
        var updatedAt: Date

        init(id: UUID, displayName: String, preferredCurrency: String, firstWeekday: Int, storageMode: String, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.displayName = displayName
            self.preferredCurrency = preferredCurrency
            self.firstWeekday = firstWeekday
            self.storageMode = storageMode
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class AccountRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var typeRaw: String
        var currencyCode: String
        var openingBalanceMinor: Int64
        var sortOrder: Int
        var archivedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var deletedAt: Date?

        init(id: UUID, name: String, typeRaw: String, currencyCode: String, openingBalanceMinor: Int64, sortOrder: Int, archivedAt: Date?, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.name = name
            self.typeRaw = typeRaw
            self.currencyCode = currencyCode
            self.openingBalanceMinor = openingBalanceMinor
            self.sortOrder = sortOrder
            self.archivedAt = archivedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.version = 1
            self.deletedAt = nil
        }
    }

    @Model
    final class CategoryRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var kindRaw: String
        var icon: String
        var colorHex: String?
        var isSystem: Bool
        var sortOrder: Int
        var archivedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var deletedAt: Date?

        init(id: UUID, name: String, kindRaw: String, icon: String, colorHex: String?, isSystem: Bool, sortOrder: Int, archivedAt: Date?, createdAt: Date) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.icon = icon
            self.colorHex = colorHex
            self.isSystem = isSystem
            self.sortOrder = sortOrder
            self.archivedAt = archivedAt
            self.createdAt = createdAt
            self.updatedAt = createdAt
            self.version = 1
            self.deletedAt = nil
        }
    }

    @Model
    final class TransactionRecord {
        #Index<TransactionRecord>([\.occurredAt], [\.accountId], [\.categoryId], [\.kindRaw])

        @Attribute(.unique) var id: UUID
        var kindRaw: String
        var amountMinor: Int64
        var currencyCode: String
        var occurredAt: Date
        var occurredTimeZone: String
        var accountId: UUID
        var counterpartAccountId: UUID?
        var categoryId: UUID?
        var merchant: String?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var deletedAt: Date?

        init(id: UUID, kindRaw: String, amountMinor: Int64, currencyCode: String, occurredAt: Date, occurredTimeZone: String, accountId: UUID, counterpartAccountId: UUID?, categoryId: UUID?, merchant: String?, notes: String?, createdAt: Date, updatedAt: Date, deletedAt: Date?) {
            self.id = id
            self.kindRaw = kindRaw
            self.amountMinor = amountMinor
            self.currencyCode = currencyCode
            self.occurredAt = occurredAt
            self.occurredTimeZone = occurredTimeZone
            self.accountId = accountId
            self.counterpartAccountId = counterpartAccountId
            self.categoryId = categoryId
            self.merchant = merchant
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.version = 1
            self.deletedAt = deletedAt
        }
    }

    @Model
    final class ReceiptRecord {
        #Index<ReceiptRecord>([\.transactionId])

        @Attribute(.unique) var id: UUID
        var transactionId: UUID
        var fileName: String
        var contentTypeRaw: String
        var fileSize: Int64
        var uploadStateRaw: String
        var storagePath: String?
        var createdAt: Date

        init(id: UUID, transactionId: UUID, fileName: String, contentTypeRaw: String, fileSize: Int64, uploadStateRaw: String, createdAt: Date) {
            self.id = id
            self.transactionId = transactionId
            self.fileName = fileName
            self.contentTypeRaw = contentTypeRaw
            self.fileSize = fileSize
            self.uploadStateRaw = uploadStateRaw
            self.storagePath = nil
            self.createdAt = createdAt
        }
    }
}

typealias ProfileRecord = SchemaV1.ProfileRecord
typealias AccountRecord = SchemaV1.AccountRecord
typealias CategoryRecord = SchemaV1.CategoryRecord
typealias TransactionRecord = SchemaV1.TransactionRecord
typealias ReceiptRecord = SchemaV1.ReceiptRecord

/// Add a new `VersionedSchema` and a `MigrationStage` here for every schema change.
enum MyExpenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum PersistenceFactory {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: MyExpenseMigrationPlan.self, configurations: configuration)
    }
}
