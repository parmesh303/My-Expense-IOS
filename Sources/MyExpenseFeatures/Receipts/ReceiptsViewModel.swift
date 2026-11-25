import Foundation
import MyExpenseCore
import Observation

/// Attach, view and remove receipts for one transaction (FR-090…FR-096).
@MainActor
@Observable
public final class ReceiptsViewModel {
    public private(set) var receipts: [Receipt] = []
    public private(set) var errorMessage: String?

    public let transactionId: UUID
    private let container: AppContainer

    public init(container: AppContainer, transactionId: UUID) {
        self.container = container
        self.transactionId = transactionId
    }

    public var canAttachMore: Bool { receipts.count < ReceiptValidator.maxAttachmentsPerTransaction }

    public func load() {
        do {
            receipts = try container.receipts.receipts(transactionId: transactionId)
        } catch {
            errorMessage = "Receipts could not be loaded."
        }
    }

    public func fileURL(for receipt: Receipt) -> URL {
        container.receiptFiles.url(for: receipt.fileName)
    }

    /// Validates and stores an attachment. If saving the record fails the file is removed,
    /// so no orphaned files are left behind.
    @discardableResult
    public func attach(data: Data, typeIdentifier: String) -> Bool {
        errorMessage = nil
        let type: ReceiptContentType
        do {
            type = try ReceiptValidator.validate(typeIdentifier: typeIdentifier, size: Int64(data.count), existingCount: receipts.count)
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
        let id = UUID()
        let fileName: String
        do {
            fileName = try container.receiptFiles.write(data, receiptId: id, contentType: type)
        } catch {
            errorMessage = "The receipt could not be saved on this device."
            return false
        }
        let receipt = Receipt(id: id, transactionId: transactionId, fileName: fileName, contentType: type, fileSize: Int64(data.count), createdAt: container.clock())
        do {
            try container.receipts.save(receipt)
        } catch {
            try? container.receiptFiles.delete(fileName: fileName)
            errorMessage = "The receipt could not be saved. Please try again."
            return false
        }
        receipts.append(receipt)
        return true
    }

    public func remove(_ receipt: Receipt) {
        errorMessage = nil
        do {
            try container.receipts.delete(id: receipt.id)
            receipts.removeAll { $0.id == receipt.id }
            // The record is gone; a leftover file is harmless, so file errors are ignored.
            try? container.receiptFiles.delete(fileName: receipt.fileName)
        } catch {
            errorMessage = "The receipt could not be removed."
        }
    }

    public func reportImportFailure() {
        errorMessage = "The selected file could not be read."
    }

    static func message(for error: ReceiptValidationError) -> String {
        switch error {
        case .unsupportedType: "Only JPEG, PNG, HEIC images and PDF files can be attached."
        case .emptyFile: "The selected file is empty."
        case .tooLarge(let maxBytes): "Receipts must be \(ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)) or smaller."
        case .tooManyAttachments(let max): "You can attach up to \(max) receipts per transaction."
        }
    }
}
