import Foundation

/// Supported receipt formats (FR-096). Raw values are Uniform Type Identifiers.
public enum ReceiptContentType: String, Codable, Sendable, CaseIterable {
    case jpeg = "public.jpeg"
    case png = "public.png"
    case heic = "public.heic"
    case pdf = "com.adobe.pdf"

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .pdf: "pdf"
        }
    }

    public var isImage: Bool { self != .pdf }
}

/// Upload status for cloud backup (FR-094). Phase 2 only creates `.localOnly` receipts.
public enum ReceiptUploadState: String, Codable, Sendable {
    case localOnly = "local_only", pending, uploaded, failed
}

public struct Receipt: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var transactionId: UUID
    /// File name inside the app's private receipts directory.
    public var fileName: String
    public var contentType: ReceiptContentType
    public var fileSize: Int64
    public var uploadState: ReceiptUploadState
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        transactionId: UUID,
        fileName: String,
        contentType: ReceiptContentType,
        fileSize: Int64,
        uploadState: ReceiptUploadState = .localOnly,
        createdAt: Date = .now
    ) {
        self.id = id
        self.transactionId = transactionId
        self.fileName = fileName
        self.contentType = contentType
        self.fileSize = fileSize
        self.uploadState = uploadState
        self.createdAt = createdAt
    }
}

public enum ReceiptValidationError: Error, Equatable, Sendable {
    case unsupportedType
    case emptyFile
    case tooLarge(maxBytes: Int64)
    case tooManyAttachments(max: Int)
}

public enum ReceiptValidator {
    public static let maxFileSize: Int64 = 10 * 1024 * 1024
    public static let maxAttachmentsPerTransaction = 5

    /// Returns the receipt type for an attachment, or throws a user-presentable reason (FR-096).
    public static func validate(typeIdentifier: String, size: Int64, existingCount: Int) throws(ReceiptValidationError) -> ReceiptContentType {
        guard let type = ReceiptContentType(rawValue: typeIdentifier) else { throw .unsupportedType }
        guard size > 0 else { throw .emptyFile }
        guard size <= maxFileSize else { throw .tooLarge(maxBytes: maxFileSize) }
        guard existingCount < maxAttachmentsPerTransaction else { throw .tooManyAttachments(max: maxAttachmentsPerTransaction) }
        return type
    }
}
