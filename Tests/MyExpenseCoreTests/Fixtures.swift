import Foundation
import Testing
@testable import MyExpenseCore

enum Fixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static func inr(_ rupees: Int64) -> Money { Money(minorUnits: rupees * 100, currency: .inr) }

    static let bank = Account(name: "HDFC", type: .bank, openingBalanceMinor: 10_000_00)
    static let cash = Account(name: "Cash", type: .cash, openingBalanceMinor: 500_00)
    static let card = Account(name: "Visa", type: .creditCard, openingBalanceMinor: -2_000_00)
    static let usdAccount = Account(name: "USD", type: .bank, currency: .usd)
    static let food = TransactionCategory(name: "Food", kind: .expense, icon: "fork.knife")
    static let rent = TransactionCategory(name: "Rent", kind: .expense, icon: "house")
    static let salary = TransactionCategory(name: "Salary", kind: .income, icon: "briefcase")
}
