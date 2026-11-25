import Foundation
import MyExpenseCore

/// Stores receipt files in a private directory with complete file protection (FR-092, SEC-009).
public struct FileReceiptStore: ReceiptFileStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/Receipts`, which is not visible in the Files app.
    public static func defaultDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Receipts", directoryHint: .isDirectory)
    }

    public func write(_ data: Data, receiptId: UUID, contentType: ReceiptContentType) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(receiptId.uuidString).\(contentType.fileExtension)"
        try data.write(to: url(for: fileName), options: [.atomic, .completeFileProtection])
        return fileName
    }

    public func url(for fileName: String) -> URL {
        // Only the last path component is used, so stored names cannot escape the directory.
        directory.appending(path: (fileName as NSString).lastPathComponent, directoryHint: .notDirectory)
    }

    public func delete(fileName: String) throws {
        let url = url(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
