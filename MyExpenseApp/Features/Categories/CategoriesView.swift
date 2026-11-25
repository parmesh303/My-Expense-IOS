import MyExpenseCore
import MyExpenseFeatures
import SwiftUI

/// Categories management: create, rename, reorder, archive (S8, FR-050…FR-055).
struct CategoriesView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: CategoriesViewModel?
    @State private var editing: TransactionCategory?
    @State private var creating = false

    var body: some View {
        Group {
            if let model {
                CategoryList(model: model, editing: $editing)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Label("Add Category", systemImage: "plus") }
            }
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $creating) {
            CategoryFormView(container: container, kind: model?.kind ?? .expense, category: nil)
        }
        .sheet(item: $editing) { category in
            CategoryFormView(container: container, kind: category.kind, category: category)
        }
        .task(id: container.dataVersion) {
            if model == nil { model = CategoriesViewModel(container: container) }
            model?.load()
        }
    }
}

private struct CategoryList: View {
    @Bindable var model: CategoriesViewModel
    @Binding var editing: TransactionCategory?

    var body: some View {
        List {
            Picker("Type", selection: $model.kind) {
                Text("Expense").tag(CategoryKind.expense)
                Text("Income").tag(CategoryKind.income)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section {
                ForEach(model.active) { category in
                    row(category)
                        .swipeActions {
                            Button("Archive", systemImage: "archivebox") { model.setArchived(true, categoryId: category.id) }
                                .tint(.orange)
                        }
                }
                .onMove { model.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Tap to rename. Use Edit to reorder.")
            }

            if !model.archived.isEmpty {
                Section {
                    ForEach(model.archived) { category in
                        row(category)
                            .foregroundStyle(.secondary)
                            .swipeActions {
                                Button("Restore", systemImage: "arrow.uturn.backward") { model.setArchived(false, categoryId: category.id) }
                                    .tint(Theme.accent)
                            }
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Archived categories stay on past transactions but can't be chosen for new ones.")
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.expense)
            }
        }
    }

    private func row(_ category: TransactionCategory) -> some View {
        Button {
            editing = category
        } label: {
            Label {
                Text(category.name)
            } icon: {
                Image(systemName: category.icon).foregroundStyle(Color(hex: category.colorHex) ?? Theme.accent)
            }
        }
        .tint(.primary)
    }
}

struct CategoryFormView: View {
    @State private var model: CategoryFormViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, kind: CategoryKind, category: TransactionCategory?) {
        _model = State(initialValue: CategoryFormViewModel(container: container, kind: kind, editing: category))
    }

    private let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name)
                } footer: {
                    Text(model.kind == .expense ? "Expense category" : "Income category")
                }

                Section("Color") {
                    LazyVGrid(columns: columns) {
                        ForEach(CategoryFormViewModel.colorChoices, id: \.self) { hex in
                            Button {
                                model.colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if model.colorHex == hex {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(model.colorHex == hex ? .isSelected : [])
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: columns) {
                        ForEach(CategoryFormViewModel.iconChoices, id: \.self) { icon in
                            Button {
                                model.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(model.icon == icon ? .white : .primary)
                                    .background(model.icon == icon ? (Color(hex: model.colorHex) ?? Theme.accent) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(model.icon == icon ? .isSelected : [])
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.expense) }
                }
            }
            .navigationTitle(model.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.save() { dismiss() } }
                }
            }
        }
    }
}
