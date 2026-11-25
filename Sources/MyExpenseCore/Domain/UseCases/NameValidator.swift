import Foundation

public enum NameValidationError: Error, Equatable, Sendable {
    case empty
    case tooLong(max: Int)
    case duplicate
}

/// Name rules for accounts (FR-041) and categories (FR-051).
public enum NameValidator {
    public static let maxAccountNameLength = 60
    public static let maxCategoryNameLength = 40

    /// Returns the trimmed name. Duplicates are compared case- and diacritic-insensitively
    /// against active (non-archived) names, excluding the item being edited.
    public static func validate(_ name: String, maxLength: Int, existingNames: [String]) throws(NameValidationError) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        guard trimmed.count <= maxLength else { throw .tooLong(max: maxLength) }
        let isDuplicate = existingNames.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !isDuplicate else { throw .duplicate }
        return trimmed
    }

    public static func accountName(_ name: String, editing id: UUID?, among accounts: [Account]) throws(NameValidationError) -> String {
        let others = accounts.filter { $0.id != id && !$0.isArchived }.map(\.name)
        return try validate(name, maxLength: maxAccountNameLength, existingNames: others)
    }

    public static func categoryName(_ name: String, kind: CategoryKind, editing id: UUID?, among categories: [TransactionCategory]) throws(NameValidationError) -> String {
        let others = categories.filter { $0.id != id && !$0.isArchived && $0.kind == kind }.map(\.name)
        return try validate(name, maxLength: maxCategoryNameLength, existingNames: others)
    }
}
