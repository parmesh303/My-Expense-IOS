import MyExpenseCore
import SwiftUI

/// Design tokens for a calm, minimal finance UI (SRS §11.3).
enum Theme {
    static let accent = Color(red: 0.11, green: 0.49, blue: 0.43)
    static let income = Color.green
    static let expense = Color.red
    static let transfer = Color.secondary

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Color {
    /// Parses "#RRGGBB"; returns nil for anything else.
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Rounded card container used across screens.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

extension CurrencyCode {
    var localizedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }
}

enum WeekdayOptions {
    /// (Calendar weekday number, localized name) for Sunday…Saturday.
    static var all: [(Int, String)] {
        Calendar.current.weekdaySymbols.enumerated().map { ($0.offset + 1, $0.element) }
    }
}
