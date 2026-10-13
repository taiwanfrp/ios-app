import Foundation
import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case blue
    case blueLight
    case green
    case greenLight
    case oled
    case white

    var id: Self { self }

    static let basicThemes: [AppTheme] = [.light, .dark, .system]
    static let darkThemes: [AppTheme] = [.blue, .green, .oled]
    static let lightThemes: [AppTheme] = [.blueLight, .greenLight, .white]

    var title: String {
        switch self {
        case .system: L10n.text("系統", "System")
        case .light: L10n.text("淺色", "Light")
        case .dark: L10n.text("深色", "Dark")
        case .blue: L10n.text("藍色", "Blue")
        case .blueLight: L10n.text("湖水藍", "Blue Light")
        case .green: L10n.text("綠色", "Green")
        case .greenLight: L10n.text("薄荷綠", "Mint Green")
        case .oled: L10n.text("極致黑", "OLED Black")
        case .white: L10n.text("極致白", "Pure White")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .blueLight, .greenLight, .white: .light
        case .dark, .blue, .green, .oled: .dark
        }
    }

    /// 「系統」主題沒有自己的配色，而是依 iOS 目前的外觀套用「淺色」或「深色」主題。
    /// 使用動態顏色，系統切換深淺色時會即時跟著變。
    private func followingSystem(_ color: (AppTheme) -> Color) -> Color {
        Color(light: color(.light), dark: color(.dark))
    }

    var accentColor: Color {
        switch self {
        case .system: followingSystem(\.accentColor)
        case .light: Color(hex: 0x6750A4)
        case .dark: Color(hex: 0xD0BCFF)
        case .blue: Color(hex: 0x58A6FF)
        case .blueLight: Color(hex: 0x5865F2)
        case .green: Color(hex: 0x2ECC71)
        case .greenLight: Color(hex: 0x27AE60)
        case .oled: .white
        case .white: .black
        }
    }

    var onAccentColor: Color {
        switch self {
        case .system: followingSystem(\.onAccentColor)
        case .light, .blueLight, .greenLight, .white: .white
        case .dark: Color(hex: 0x381E72)
        case .blue, .green, .oled: .black
        }
    }

    var secondaryColor: Color {
        switch self {
        case .system: followingSystem(\.secondaryColor)
        case .light: Color(hex: 0x7D5260)
        case .dark: Color(hex: 0xEFB8C8)
        case .blue: Color(hex: 0x1F6FEB)
        case .blueLight: Color(hex: 0x7289DA)
        case .green: Color(hex: 0x27AE60)
        case .greenLight: Color(hex: 0x58D68D)
        case .oled: .gray
        case .white: .gray
        }
    }

    var backgroundColor: Color? {
        switch self {
        case .system, .light, .dark: nil
        case .blue: Color(hex: 0x0D1117)
        case .blueLight: Color(hex: 0xF0F2FF)
        case .green: Color(hex: 0x0A1A12)
        case .greenLight: Color(hex: 0xF0FFF4)
        case .oled: .black
        case .white: .white
        }
    }

    var surfaceColor: Color? {
        switch self {
        case .system, .light, .dark: nil
        case .blue: Color(hex: 0x161B22)
        case .blueLight: Color(hex: 0xE3E5F1)
        case .green: Color(hex: 0x12261E)
        case .greenLight: Color(hex: 0xD5F5E3)
        case .oled: Color(hex: 0x1A1A1A)
        case .white: Color(hex: 0xF0F0F0)
        }
    }

    var showsGlow: Bool {
        self != .oled && self != .white
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case auto
    case traditionalChinese
    case english

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: L10n.text("系統預設", "System")
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        }
    }

    var usesEnglish: Bool {
        switch self {
        case .auto: Locale.preferredLanguages.first?.hasPrefix("en") == true
        case .traditionalChinese: false
        case .english: true
        }
    }

    var locale: Locale {
        usesEnglish ? Locale(identifier: "en") : Locale(identifier: "zh-Hant-TW")
    }
}

enum L10n {
    static let languageKey = "taiwanfrp.language"

    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .auto
    }

    static func text(_ traditionalChinese: String, _ english: String) -> String {
        language.usesEnglish ? english : traditionalChinese
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "taiwanfrp.theme")
        }
    }
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: L10n.languageKey)
        }
    }
    @Published var refreshInterval: Int {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "taiwanfrp.refreshInterval")
        }
    }
    @Published var singleExpandMode: Bool {
        didSet {
            UserDefaults.standard.set(singleExpandMode, forKey: "taiwanfrp.singleExpandMode")
        }
    }
    @Published var autoCheckUpdate: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckUpdate, forKey: "taiwanfrp.autoCheckUpdate")
        }
    }

    func text(_ traditionalChinese: String, _ english: String) -> String {
        language.usesEnglish ? english : traditionalChinese
    }

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: "taiwanfrp.theme") ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: rawValue) ?? .system
        language = L10n.language
        refreshInterval = max(UserDefaults.standard.object(forKey: "taiwanfrp.refreshInterval") as? Int ?? 60, 10)
        singleExpandMode = UserDefaults.standard.object(forKey: "taiwanfrp.singleExpandMode") as? Bool ?? true
        autoCheckUpdate = UserDefaults.standard.object(forKey: "taiwanfrp.autoCheckUpdate") as? Bool ?? true
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 依目前介面的深淺色自動切換的顏色。
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
