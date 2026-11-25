import MyExpenseCore
import MyExpenseFeatures
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// Receipt attachments for a transaction (FR-090…FR-096).
/// The photo picker and document picker run out of process, so no photo-library permission
/// prompt is needed (FR-091, SEC-008).
struct ReceiptsSection: View {
    @State private var model: ReceiptsViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var importingFile = false
    @State private var previewURL: URL?
    @State private var pendingRemoval: Receipt?
    @State private var isImporting = false

    private static let importableTypes: [UTType] = [.pdf, .jpeg, .png, .heic]

    init(container: AppContainer, transactionId: UUID) {
        _model = State(initialValue: ReceiptsViewModel(container: container, transactionId: transactionId))
    }

    var body: some View {
        Section {
            ForEach(model.receipts) { receipt in
                Button {
                    previewURL = model.fileURL(for: receipt)
                } label: {
                    HStack {
                        Image(systemName: receipt.contentType.isImage ? "photo" : "doc.richtext")
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(receipt.contentType.isImage ? "Photo" : "PDF")
                            Text("\(ByteCountFormatter.string(fromByteCount: receipt.fileSize, countStyle: .file)) · On this iPhone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions {
                    Button("Remove", systemImage: "trash", role: .destructive) { pendingRemoval = receipt }
                }
            }

            if isImporting {
                HStack { ProgressView(); Text("Adding receipt…").foregroundStyle(.secondary) }
            }

            if model.canAttachMore {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                }
                Button {
                    importingFile = true
                } label: {
                    Label("Add File (PDF or Image)", systemImage: "doc.badge.plus")
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .foregroundStyle(Theme.expense)
            }
        } header: {
            Text("Receipts")
        } footer: {
            Text("Up to \(ReceiptValidator.maxAttachmentsPerTransaction) files, \(ByteCountFormatter.string(fromByteCount: ReceiptValidator.maxFileSize, countStyle: .file)) each. Receipts are stored only on this iPhone.")
        }
        .task { model.load() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: Self.importableTypes) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure: model.reportImportFailure()
            }
        }
        .quickLookPreview($previewURL)
        .confirmationDialog(
            "Remove this receipt?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { receipt in
            Button("Remove", role: .destructive) { model.remove(receipt) }
        } message: { _ in
            Text("The file will be deleted from this iPhone.")
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            photoItem = nil
        }
        let supported = Set(ReceiptContentType.allCases.map(\.rawValue))
        let typeIdentifier = item.supportedContentTypes.map(\.identifier).first { supported.contains($0) }
            ?? item.supportedContentTypes.first?.identifier
            ?? ""
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                model.reportImportFailure()
                return
            }
            model.attach(data: data, typeIdentifier: typeIdentifier)
        } catch {
            model.reportImportFailure()
        }
    }

    private func importFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            model.reportImportFailure()
            return
        }
        let typeIdentifier = UTType(filenameExtension: url.pathExtension)?.identifier ?? ""
        model.attach(data: data, typeIdentifier: typeIdentifier)
    }
}
