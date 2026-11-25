import Foundation
import MyExpenseCore
import Observation

/// Categories screen: list, reorder, archive (FR-050…FR-055).
@MainActor
@Observable
public final class CategoriesViewModel {
    public var kind: CategoryKind = .expense {
        didSet { if kind != oldValue { load() } }
    }
    public private(set) var active: [TransactionCategory] = []
    public private(set) var archived: [TransactionCategory] = []
    public private(set) var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func load() {
        do {
            let all = try container.categories.all(includeArchived: true)
                .filter { $0.kind == kind }
                .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            active = all.filter { !$0.isArchived }
            archived = all.filter { $0.isArchived }
            errorMessage = nil
        } catch {
            errorMessage = "Categories could not be loaded."
        }
    }

    /// Persists a new order for active categories (List `onMove`).
    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = active
        let moving = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) { reordered.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: insertAt)
        do {
            for (index, var category) in reordered.enumerated() where category.sortOrder != index {
                category.sortOrder = index
                try container.categories.save(category)
            }
            container.dataDidChange()
            load()
        } catch {
            errorMessage = "The new order could not be saved."
            load()
        }
    }

    /// Archived categories stay on historical transactions (FR-054).
    public func setArchived(_ archived: Bool, categoryId: UUID) {
        do {
            if !archived, let category = self.archived.first(where: { $0.id == categoryId }) {
                // Restoring must not create two active categories with the same name.
                _ = try NameValidator.categoryName(category.name, kind: category.kind, editing: category.id, among: try container.categories.all(includeArchived: true))
            }
            try container.categories.setArchived(archived, id: categoryId)
            container.dataDidChange()
            load()
        } catch let error as NameValidationError {
            errorMessage = NameValidationMessages.message(for: error, noun: "category")
        } catch {
            errorMessage = "The category could not be updated."
        }
    }
}

/// Create/edit a category (FR-051, FR-052).
@MainActor
@Observable
public final class CategoryFormViewModel {
    public static let iconChoices = [
        "fork.knife", "cart", "bag", "airplane", "car", "fuelpump", "bus", "house", "bolt", "drop", "wifi", "phone",
        "cross.case", "pills", "film", "gamecontroller", "music.note", "book", "graduationcap", "gift", "heart",
        "pawprint", "tshirt", "scissors", "sparkles", "dumbbell", "briefcase", "laptopcomputer", "storefront",
        "percent", "banknote", "creditcard", "building.columns", "wrench.and.screwdriver", "leaf", "ellipsis.circle",
    ]
    public static let colorChoices = [
        "#EF4444", "#F97316", "#EAB308", "#22C55E", "#14B8A6", "#0EA5E9", "#3B82F6", "#8B5CF6", "#EC4899", "#64748B",
    ]

    public var name: String
    public var icon: String
    public var colorHex: String?
    public private(set) var errorMessage: String?

    public let kind: CategoryKind
    public let isEditing: Bool
    private let original: TransactionCategory?
    private let container: AppContainer

    public init(container: AppContainer, kind: CategoryKind, editing category: TransactionCategory? = nil) {
        self.container = container
        self.kind = category?.kind ?? kind
        original = category
        isEditing = category != nil
        name = category?.name ?? ""
        icon = category?.icon ?? "ellipsis.circle"
        colorHex = category?.colorHex ?? Self.colorChoices[5]
    }

    public var title: String { isEditing ? "Edit Category" : "New Category" }

    @discardableResult
    public func save() -> Bool {
        errorMessage = nil
        do {
            let all = try container.categories.all(includeArchived: true)
            let validName = try NameValidator.categoryName(name, kind: kind, editing: original?.id, among: all)
            let category = TransactionCategory(
                id: original?.id ?? UUID(),
                name: validName,
                kind: kind,
                icon: icon,
                colorHex: colorHex,
                isSystem: original?.isSystem ?? false,
                sortOrder: original?.sortOrder ?? (all.filter { $0.kind == kind }.map(\.sortOrder).max() ?? -1) + 1,
                archivedAt: original?.archivedAt
            )
            try container.categories.save(category)
            container.dataDidChange()
            return true
        } catch let error as NameValidationError {
            errorMessage = NameValidationMessages.message(for: error, noun: "category")
        } catch {
            errorMessage = "The category could not be saved. Please try again."
        }
        return false
    }
}
