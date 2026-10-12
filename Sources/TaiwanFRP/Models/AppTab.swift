import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case nodes
    case tunnels
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: L10n.text("主頁", "Home")
        case .nodes: L10n.text("節點", "Nodes")
        case .tunnels: L10n.text("隧道", "Tunnels")
        case .settings: L10n.text("設定", "Settings")
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .nodes: "server.rack"
        case .tunnels: "arrow.triangle.branch"
        case .settings: "gearshape.fill"
        }
    }
}
