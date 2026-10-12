import SwiftUI

struct HomePage: View {
    let onNavigate: (AppTab) -> Void
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(verbatim: "\(settings.text("歡迎回來", "Welcome back")), \(viewModel.user?.username ?? settings.text("使用者", "User"))")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        DashboardCard(
                            title: AppTab.nodes.title,
                            icon: AppTab.nodes.icon,
                            color: settings.theme.accentColor,
                            active: viewModel.nodes.filter { $0.status == "active" }.count,
                            total: viewModel.nodes.count
                        ) { onNavigate(.nodes) }
                        DashboardCard(
                            title: AppTab.tunnels.title,
                            icon: AppTab.tunnels.icon,
                            color: settings.theme.secondaryColor,
                            active: viewModel.tunnels.filter { $0.status == "active" }.count,
                            total: viewModel.tunnels.count
                        ) { onNavigate(.tunnels) }
                    }
                }

                SystemStatusCard(status: viewModel.systemStatus)

                VStack(alignment: .leading, spacing: 12) {
                    Text(settings.text("🔗 官方連結", "🔗 Official Links"))
                        .font(.headline)
                    Link(destination: Links.website) {
                        Label(settings.text("官方網站", "Official Website"), systemImage: "safari.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(FilledButtonStyle(background: settings.theme.accentColor, foreground: settings.theme.onAccentColor))

                    Link(destination: Links.discord) {
                        Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(FilledButtonStyle(background: .discordBlurple, foreground: .white))

                    Link(destination: Links.github) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(FilledButtonStyle(background: colorScheme == .dark ? Color(white: 0.28) : .black, foreground: .white))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable { await viewModel.refresh() }
        .background(AppGlassBackground())
        .navigationTitle(Text(verbatim: "TaiwanFRP"))
        .profileToolbar(isPresented: $showingProfile)
    }
}

private struct DashboardCard: View {
    let title: String
    let icon: String
    let color: Color
    let active: Int
    let total: Int
    let action: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.headline)
                Text(verbatim: "\(active) / \(total)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(settings.text("運行中 / 總計", "Active / Total"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassCard(interactive: true)
    }
}

private struct SystemStatusCard: View {
    let status: SystemStatusResponse?
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.text("🛠️ 系統狀況", "🛠️ System Status"))
                .font(.headline)
            StatusLine(title: "API", value: status?.api)
            StatusLine(title: settings.text("資料庫", "Database"), value: status?.database)
            StatusLine(title: "Redis", value: status?.redis)
            HStack {
                Text(settings.text("版本", "Version"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: status?.version ?? "N/A")
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }
}

private struct StatusLine: View {
    let title: String
    let value: String?
    @EnvironmentObject private var settings: AppSettings

    private var isUp: Bool {
        value == "ok" || value == "up"
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: value == nil ? .gray : isUp ? .green : .red)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value ?? settings.text("檢查中", "Checking"))
                .fontWeight(.medium)
        }
    }
}
