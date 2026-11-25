import Foundation
import Testing
@testable import MyExpenseCore

@Suite struct MoneyTests {
    @Test(arguments: [
        ("1,234.50", Int64(123_450)),
        ("1,00,000", Int64(10_000_000)),
        ("0.005", Int64(0)),      // half-even rounds down to 0
        ("0.015", Int64(2)),      // half-even rounds up to 2
        ("99.999", Int64(10_000)),
        ("  42 ", Int64(4_200)),
    ])
    func parsesAndRoundsINR(text: String, expected: Int64) throws {
        #expect(try Money(parsing: text, currency: .inr).minorUnits == expected)
    }

    @Test(arguments: ["", "abc", "1.2.3", "₹100", "1e5", "."])
    func rejectsInvalidText(text: String) {
        #expect(throws: MoneyError.invalidNumber) { try Money(parsing: text, currency: .inr) }
    }

    @Test func zeroDecimalCurrencyRounds() throws {
        let jpy = try #require(CurrencyCode(rawValue: "jpy"))
        #expect(try Money(parsing: "1234.5", currency: jpy).minorUnits == 1234)
    }

    @Test func decimalRoundTripIsExact() throws {
        let money = try Money(parsing: "0.10", currency: .inr)
        let sum = try money.adding(money).adding(money)
        #expect(sum.decimalValue == Decimal(string: "0.3"))
    }

    @Test func addingDifferentCurrenciesFails() {
        #expect(throws: MoneyError.currencyMismatch) {
            try Fixtures.inr(1).adding(Money(minorUnits: 1, currency: .usd))
        }
    }

    @Test func overflowIsDetected() {
        #expect(throws: MoneyError.overflow) {
            try Money(minorUnits: .max, currency: .inr).adding(Money(minorUnits: 1, currency: .inr))
        }
    }

    @Test func formatsIndianGrouping() {
        #expect(Money(minorUnits: 12_345_678_90, currency: .inr).formatted() == "₹1,23,45,678.90")
    }

    @Test func invalidCurrencyCodeRejected() {
        #expect(CurrencyCode(rawValue: "RUPEE") == nil)
        #expect(CurrencyCode(rawValue: "IN1") == nil)
    }
}

@Suite struct ProfileTests {
    @Test func validation() {
        #expect(throws: Never.self) { try Profile(displayName: "Parmesh").validate() }
        #expect(throws: Profile.ValidationError.emptyName) { try Profile(displayName: "   ").validate() }
        #expect(throws: Profile.ValidationError.nameTooLong) {
            try Profile(displayName: String(repeating: "a", count: 51)).validate()
        }
        #expect(throws: Profile.ValidationError.invalidFirstWeekday) {
            try Profile(displayName: "A", firstWeekday: 8).validate()
        }
    }
}

@Suite struct DefaultCategoriesTests {
    @Test func containsSRSDefaults() {
        let categories = DefaultCategories.make()
        let expense = categories.filter { $0.kind == .expense }.map(\.name)
        let income = categories.filter { $0.kind == .income }.map(\.name)
        #expect(expense.count == 12)
        #expect(expense.contains("EMI/Loans"))
        #expect(income == ["Salary", "Freelance", "Business", "Interest", "Gift", "Other Income"])
        #expect(categories.allSatisfy { $0.isSystem })
        #expect(Set(categories.map(\.id)).count == categories.count)
    }

    @Test @MainActor func seedingIsIdempotent() throws {
        let repository = InMemoryCategoryRepository()
        try repository.seedDefaultsIfNeeded()
        try repository.seedDefaultsIfNeeded()
        #expect(try repository.all(includeArchived: true).count == DefaultCategories.make().count)
    }
}
