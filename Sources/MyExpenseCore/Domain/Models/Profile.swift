import Foundation

public enum StorageMode: String, Codable, Sendable {
    /// Data lives only on this device and is not backed up (FR-005, FR-106).
    case localOnly = "local"
    case cloud
}

public struct Profile: Hashable, Codable, Sendable {
    public var id: UUID
    public var displayName: String
    public var preferredCurrency: CurrencyCode
    /// 1 = Sunday … 7 = Saturday (Calendar convention).
    public var firstWeekday: Int
    public var storageMode: StorageMode
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        preferredCurrency: CurrencyCode = .inr,
        firstWeekday: Int = 2,
        storageMode: StorageMode = .localOnly,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.preferredCurrency = preferredCurrency
        self.firstWeekday = firstWeekday
        self.storageMode = storageMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case emptyName, nameTooLong, invalidFirstWeekday
    }

    public static let maxNameLength = 50

    public func validate() throws(ValidationError) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw .emptyName }
        if trimmed.count > Self.maxNameLength { throw .nameTooLong }
        if !(1...7).contains(firstWeekday) { throw .invalidFirstWeekday }
    }
}
