import Foundation
import MyExpenseCore

/// Converts between SwiftData records and domain values. Unknown raw values are treated as
/// corrupt data rather than silently defaulted, so financial records are never misread.
enum RecordMappingError: Error {
    case invalidValue(entity: String, field: String)
}

extension ProfileRecord {
    convenience init(_ profile: Profile) {
        self.init(
            id: profile.id,
            displayName: profile.displayName,
            preferredCurrency: profile.preferredCurrency.rawValue,
            firstWeekday: profile.firstWeekday,
            storageMode: profile.storageMode.rawValue,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    func apply(_ profile: Profile) {
        displayName = profile.displayName
        preferredCurrency = profile.preferredCurrency.rawValue
        firstWeekday = profile.firstWeekday
        storageMode = profile.storageMode.rawValue
        updatedAt = profile.updatedAt
    }

    func toDomain() throws -> Profile {
        guard let currency = CurrencyCode(rawValue: preferredCurrency) else {
            throw RecordMappingError.invalidValue(entity: "Profile", field: "preferredCurrency")
        }
        guard let mode = StorageMode(rawValue: storageMode) else {
            throw RecordMappingError.invalidValue(entity: "Profile", field: "storageMode")
        }
        return Profile(id: id, displayName: displayName, preferredCurrency: currency, firstWeekday: firstWeekday, storageMode: mode, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension AccountRecord {
    convenience init(_ account: Account) {
        self.init(
            id: account.id,
            name: account.name,
            typeRaw: account.type.rawValue,
            currencyCode: account.currency.rawValue,
            openingBalanceMinor: account.openingBalanceMinor,
            sortOrder: account.sortOrder,
            archivedAt: account.archivedAt,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt
        )
    }

    func apply(_ account: Account, now: Date) {
        name = account.name
        typeRaw = account.type.rawValue
        currencyCode = account.currency.rawValue
        openingBalanceMinor = account.openingBalanceMinor
        sortOrder = account.sortOrder
        archivedAt = account.archivedAt
        updatedAt = now
        version += 1
    }

    func toDomain() throws -> Account {
        guard let type = AccountType(rawValue: typeRaw) else {
            throw RecordMappingError.invalidValue(entity: "Account", field: "type")
        }
        guard let currency = CurrencyCode(rawValue: currencyCode) else {
            throw RecordMappingError.invalidValue(entity: "Account", field: "currencyCode")
        }
        return Account(id: id, name: name, type: type, currency: currency, openingBalanceMinor: openingBalanceMinor, sortOrder: sortOrder, archivedAt: archivedAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension CategoryRecord {
    convenience init(_ category: TransactionCategory, now: Date) {
        self.init(
            id: category.id,
            name: category.name,
            kindRaw: category.kind.rawValue,
            icon: category.icon,
            colorHex: category.colorHex,
            isSystem: category.isSystem,
            sortOrder: category.sortOrder,
            archivedAt: category.archivedAt,
            createdAt: now
        )
    }

    func apply(_ category: TransactionCategory, now: Date) {
        name = category.name
        kindRaw = category.kind.rawValue
        icon = category.icon
        colorHex = category.colorHex
        isSystem = category.isSystem
        sortOrder = category.sortOrder
        archivedAt = category.archivedAt
        updatedAt = now
        version += 1
    }

    func toDomain() throws -> TransactionCategory {
        guard let kind = CategoryKind(rawValue: kindRaw) else {
            throw RecordMappingError.invalidValue(entity: "Category", field: "kind")
        }
        return TransactionCategory(id: id, name: name, kind: kind, icon: icon, colorHex: colorHex, isSystem: isSystem, sortOrder: sortOrder, archivedAt: archivedAt)
    }
}

extension TransactionRecord {
    convenience init(_ transaction: Transaction) {
        self.init(
            id: transaction.id,
            kindRaw: transaction.kind.rawValue,
            amountMinor: transaction.amount.minorUnits,
            currencyCode: transaction.amount.currency.rawValue,
            occurredAt: transaction.occurredAt,
            occurredTimeZone: transaction.occurredTimeZone,
            accountId: transaction.accountId,
            counterpartAccountId: transaction.counterpartAccountId,
            categoryId: transaction.categoryId,
            merchant: transaction.merchant,
            notes: transaction.notes,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt,
            deletedAt: transaction.deletedAt
        )
    }

    func apply(_ transaction: Transaction, now: Date) {
        kindRaw = transaction.kind.rawValue
        amountMinor = transaction.amount.minorUnits
        currencyCode = transaction.amount.currency.rawValue
        occurredAt = transaction.occurredAt
        occurredTimeZone = transaction.occurredTimeZone
        accountId = transaction.accountId
        counterpartAccountId = transaction.counterpartAccountId
        categoryId = transaction.categoryId
        merchant = transaction.merchant
        notes = transaction.notes
        deletedAt = transaction.deletedAt
        updatedAt = now
        version += 1
    }

    func toDomain() throws -> Transaction {
        guard let kind = TransactionKind(rawValue: kindRaw) else {
            throw RecordMappingError.invalidValue(entity: "Transaction", field: "kind")
        }
        guard let currency = CurrencyCode(rawValue: currencyCode) else {
            throw RecordMappingError.invalidValue(entity: "Transaction", field: "currencyCode")
        }
        return Transaction(
            id: id,
            kind: kind,
            amount: Money(minorUnits: amountMinor, currency: currency),
            occurredAt: occurredAt,
            occurredTimeZone: occurredTimeZone,
            accountId: accountId,
            counterpartAccountId: counterpartAccountId,
            categoryId: categoryId,
            merchant: merchant,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}

extension ReceiptRecord {
    convenience init(_ receipt: Receipt) {
        self.init(
            id: receipt.id,
            transactionId: receipt.transactionId,
            fileName: receipt.fileName,
            contentTypeRaw: receipt.contentType.rawValue,
            fileSize: receipt.fileSize,
            uploadStateRaw: receipt.uploadState.rawValue,
            createdAt: receipt.createdAt
        )
    }

    func toDomain() throws -> Receipt {
        guard let contentType = ReceiptContentType(rawValue: contentTypeRaw) else {
            throw RecordMappingError.invalidValue(entity: "Receipt", field: "contentType")
        }
        guard let uploadState = ReceiptUploadState(rawValue: uploadStateRaw) else {
            throw RecordMappingError.invalidValue(entity: "Receipt", field: "uploadState")
        }
        return Receipt(id: id, transactionId: transactionId, fileName: fileName, contentType: contentType, fileSize: fileSize, uploadState: uploadState, createdAt: createdAt)
    }
}
