import Foundation
import Testing
@testable import MyExpenseCore

@Suite struct ReceiptValidatorTests {
    @Test func acceptsSupportedTypes() throws {
        #expect(try ReceiptValidator.validate(typeIdentifier: "public.jpeg", size: 1, existingCount: 0) == .jpeg)
        #expect(try ReceiptValidator.validate(typeIdentifier: "com.adobe.pdf", size: ReceiptValidator.maxFileSize, existingCount: 4) == .pdf)
    }

    @Test func rejectsInvalidAttachments() {
        #expect(throws: ReceiptValidationError.unsupportedType) {
            try ReceiptValidator.validate(typeIdentifier: "public.mpeg-4", size: 1, existingCount: 0)
        }
        #expect(throws: ReceiptValidationError.emptyFile) {
            try ReceiptValidator.validate(typeIdentifier: "public.png", size: 0, existingCount: 0)
        }
        #expect(throws: ReceiptValidationError.tooLarge(maxBytes: ReceiptValidator.maxFileSize)) {
            try ReceiptValidator.validate(typeIdentifier: "public.png", size: ReceiptValidator.maxFileSize + 1, existingCount: 0)
        }
        #expect(throws: ReceiptValidationError.tooManyAttachments(max: 5)) {
            try ReceiptValidator.validate(typeIdentifier: "public.png", size: 1, existingCount: 5)
        }
    }
}

@Suite struct NameValidatorTests {
    @Test func trimsAndRejectsEmptyOrLong() throws {
        #expect(try NameValidator.validate("  HDFC ", maxLength: 10, existingNames: []) == "HDFC")
        #expect(throws: NameValidationError.empty) { try NameValidator.validate("   ", maxLength: 10, existingNames: []) }
        #expect(throws: NameValidationError.tooLong(max: 3)) { try NameValidator.validate("abcd", maxLength: 3, existingNames: []) }
    }

    @Test func duplicatesIgnoreCaseAndArchivedAndSelf() throws {
        let active = Account(name: "Cash", type: .cash)
        let archived = Account(name: "Old Bank", type: .bank, archivedAt: .now)
        let accounts = [active, archived]
        #expect(throws: NameValidationError.duplicate) { try NameValidator.accountName("cash ", editing: nil, among: accounts) }
        #expect(try NameValidator.accountName("Cash", editing: active.id, among: accounts) == "Cash")
        #expect(try NameValidator.accountName("old bank", editing: nil, among: accounts) == "old bank")
    }

    @Test func categoryDuplicatesAreScopedByKind() throws {
        let other = TransactionCategory(name: "Other", kind: .expense, icon: "x")
        #expect(try NameValidator.categoryName("Other", kind: .income, editing: nil, among: [other]) == "Other")
        #expect(throws: NameValidationError.duplicate) {
            try NameValidator.categoryName("other", kind: .expense, editing: nil, among: [other])
        }
    }
}
