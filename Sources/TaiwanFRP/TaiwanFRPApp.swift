import SwiftUI

@main
struct TaiwanFRPApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(settings.theme.accentColor)
                .environment(\.locale, settings.language.locale)
        }
    }
}
