import Foundation

/// ISO-4217 currency code, e.g. "INR".
public struct CurrencyCode: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        let code = rawValue.uppercased()
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        self.rawValue = code
    }

    public static let inr = CurrencyCode(rawValue: "INR")!
    public static let usd = CurrencyCode(rawValue: "USD")!

    /// Number of minor-unit digits used for storage and rounding.
    public var minorUnitDigits: Int {
        switch rawValue {
        case "JPY", "KRW", "VND", "CLP", "ISK": 0
        case "BHD", "KWD", "OMR", "JOD", "TND": 3
        default: 2
        }
    }

    public var description: String { rawValue }
}

public enum MoneyError: Error, Equatable, Sendable {
    case invalidNumber
    case overflow
    case currencyMismatch
}

/// Exact monetary amount stored as integer minor units (ADR-001).
public struct Money: Hashable, Codable, Sendable {
    public var minorUnits: Int64
    public var currency: CurrencyCode

    public init(minorUnits: Int64, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    public static func zero(_ currency: CurrencyCode) -> Money {
        Money(minorUnits: 0, currency: currency)
    }

    /// Creates money from a decimal major-unit value, rounding half-even to the currency's precision.
    public init(decimal: Decimal, currency: CurrencyCode) throws {
        var scaled = decimal * Self.scale(currency)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .bankers)
        let number = NSDecimalNumber(decimal: rounded)
        guard number.compare(NSDecimalNumber(value: Int64.max)) != .orderedDescending,
              number.compare(NSDecimalNumber(value: Int64.min)) != .orderedAscending else {
            throw MoneyError.overflow
        }
        self.init(minorUnits: number.int64Value, currency: currency)
    }

    /// Parses user-typed text such as "1,234.50" using the locale's separators.
    public init(parsing text: String, currency: CurrencyCode, locale: Locale = Locale(identifier: "en_IN")) throws {
        let grouping = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: grouping, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        guard cleaned.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            throw MoneyError.invalidNumber
        }
        try self.init(decimal: value, currency: currency)
    }

    public var decimalValue: Decimal {
        Decimal(minorUnits) / Self.scale(currency)
    }

    public var isPositive: Bool { minorUnits > 0 }
    public var negated: Money { Money(minorUnits: -minorUnits, currency: currency) }

    public func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else { throw MoneyError.currencyMismatch }
        let (sum, overflow) = minorUnits.addingReportingOverflow(other.minorUnits)
        guard !overflow else { throw MoneyError.overflow }
        return Money(minorUnits: sum, currency: currency)
    }

    public func formatted(locale: Locale = Locale(identifier: "en_IN")) -> String {
        decimalValue.formatted(
            .currency(code: currency.rawValue)
                .locale(locale)
                .precision(.fractionLength(currency.minorUnitDigits))
        )
    }

    private static func scale(_ currency: CurrencyCode) -> Decimal {
        var result = Decimal(1)
        for _ in 0..<currency.minorUnitDigits { result *= 10 }
        return result
    }
}
