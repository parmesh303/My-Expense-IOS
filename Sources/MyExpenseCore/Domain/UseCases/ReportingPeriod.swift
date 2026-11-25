import Foundation

public enum PeriodGranularity: String, Codable, Sendable, CaseIterable {
    case day, week, month, year

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

/// A half-open date range `[start, end)` used for dashboards, reports and budgets (FR-013, FR-080, FR-085).
public struct ReportingPeriod: Hashable, Codable, Sendable {
    public let start: Date
    public let end: Date
    /// `nil` for a custom range.
    public let granularity: PeriodGranularity?

    public init(start: Date, end: Date, granularity: PeriodGranularity? = nil) {
        precondition(start <= end, "Period start must not be after its end")
        self.start = start
        self.end = end
        self.granularity = granularity
    }

    /// The calendar period of `granularity` containing `date`. Use a calendar configured with the
    /// user's time zone and first weekday.
    public static func containing(_ date: Date, granularity: PeriodGranularity, calendar: Calendar) -> ReportingPeriod {
        guard let interval = calendar.dateInterval(of: granularity.component, for: date) else {
            preconditionFailure("Calendar could not compute \(granularity) interval")
        }
        return ReportingPeriod(start: interval.start, end: interval.end, granularity: granularity)
    }

    /// A custom range covering whole days from `firstDay` through `lastDay` inclusive.
    public static func custom(from firstDay: Date, through lastDay: Date, calendar: Calendar) -> ReportingPeriod {
        let start = calendar.startOfDay(for: min(firstDay, lastDay))
        let lastStart = calendar.startOfDay(for: max(firstDay, lastDay))
        let end = calendar.date(byAdding: .day, value: 1, to: lastStart)!
        return ReportingPeriod(start: start, end: end)
    }

    public func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }

    /// The equivalent period immediately before this one (FR-083).
    public func previous(calendar: Calendar) -> ReportingPeriod {
        if let granularity {
            let previousStart = calendar.date(byAdding: granularity.component, value: -1, to: start)!
            return .containing(previousStart, granularity: granularity, calendar: calendar)
        }
        let length = end.timeIntervalSince(start)
        return ReportingPeriod(start: start.addingTimeInterval(-length), end: start)
    }

    public func next(calendar: Calendar) -> ReportingPeriod {
        if let granularity {
            return .containing(end, granularity: granularity, calendar: calendar)
        }
        let length = end.timeIntervalSince(start)
        return ReportingPeriod(start: end, end: end.addingTimeInterval(length))
    }
}
