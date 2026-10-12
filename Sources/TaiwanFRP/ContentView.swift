import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingGuestNodes = false
    @State private var availableUpdate: GitHubRelease?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !viewModel.hasCheckedSession {
                    SplashView()
                } else if viewModel.hasSession {
                    if let block = viewModel.accountBlock {
                        AccountStatusPage(block: block)
                    } else {
                        MainTabView()
                    }
                } else {
                    WelcomePage(onGuest: { showingGuestNodes = true })
                }
            }
            .transition(.opacity)

            ToastOverlay(message: viewModel.toast)
        }
        .animation(.smooth, value: viewModel.hasCheckedSession)
        .animation(.smooth, value: viewModel.hasSession)
        .animation(.smooth, value: viewModel.accountBlock)
        .environmentObject(viewModel)
        .task {
            async let minimumDelay: Void? = try? Task.sleep(for: .seconds(0.8))
            await viewModel.checkSession()
            _ = await minimumDelay

            if settings.autoCheckUpdate, case .available(let release)? = try? await UpdateChecker.check() {
                availableUpdate = release
            }
        }
        .task(id: AutoRefreshKey(
            phase: scenePhase,
            isReady: viewModel.hasCheckedSession && viewModel.hasSession && viewModel.accountBlock == nil,
            interval: settings.refreshInterval
        )) {
            guard scenePhase == .active, viewModel.hasCheckedSession, viewModel.hasSession, viewModel.accountBlock == nil else { return }
            while !Task.isCancelled {
                await viewModel.refresh(isAutomatic: true)
                try? await Task.sleep(for: .seconds(settings.refreshInterval))
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.isInForeground = phase == .active
        }
        .fullScreenCover(isPresented: $showingGuestNodes) {
            GuestNodesPage()
                .environmentObject(viewModel)
        }
        .alert(
            settings.text("發現新版本", "New Version Available"),
            isPresented: Binding(get: { availableUpdate != nil }, set: { if !$0 { availableUpdate = nil } }),
            presenting: availableUpdate
        ) { release in
            if let url = release.htmlURL {
                Button(settings.text("前往查看", "View Release")) { openURL(url) }
            }
            Button(settings.text("不再自動顯示此通知", "Don't automatically show this again")) {
                settings.autoCheckUpdate = false
            }
            Button(settings.text("取消", "Cancel"), role: .cancel) {}
        } message: { release in
            Text(verbatim: settings.text("發現新版本：", "New version: ") + release.tagName
                + (release.body.map { "\n\n" + $0 } ?? ""))
        }
        .alert(settings.text("操作失敗", "Operation failed"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(settings.text("確定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? settings.text("發生未知錯誤", "An unknown error occurred"))
        }
    }
}

private struct AutoRefreshKey: Equatable {
    let phase: ScenePhase
    let isReady: Bool
    let interval: Int
}

private struct MainTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: AppTab.home) {
                NavigationStack {
                    HomePage { selectedTab = $0 }
                }
            }
            Tab(AppTab.nodes.title, systemImage: AppTab.nodes.icon, value: AppTab.nodes) {
                NavigationStack {
                    NodesPage()
                }
            }
            Tab(AppTab.tunnels.title, systemImage: AppTab.tunnels.icon, value: AppTab.tunnels) {
                NavigationStack {
                    TunnelsPage()
                }
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: AppTab.settings) {
                NavigationStack {
                    SettingsPage()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .id(settings.language)
    }
}
private struct SplashView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: "TaiwanFRP")
                .font(.system(size: 45, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
            Text(settings.text("免費內網穿透服務", "Free Intranet Penetration Service"))
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.large)
                .padding(.top, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGlassBackground())
    }
}

private struct AccountStatusPage: View {
    let block: AccountBlock
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingLogout = false

    private var color: Color {
        block == .suspended ? .yellow : .red
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Group {
                    if block == .suspended {
                        SettingsSuggestShape().fill(color, style: FillStyle(eoFill: true))
                    } else {
                        GppBadShape().fill(color, style: FillStyle(eoFill: true))
                    }
                }
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
                Text(block.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(block == .suspended ? .primary : color)

                VStack(spacing: 12) {
                    Link(destination: Links.discord) {
                        Label(settings.text("加入 Discord 群組", "Join Discord Server"), systemImage: "bubble.left.and.bubble.right.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.discordBlurple)

                    Button {
                        showingLogout = true
                    } label: {
                        Text(settings.text("登出帳號", "Logout"))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 24)
            }
            .padding(32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    AppGlassBackground()
                    if block != .suspended {
                        color.opacity(0.1).ignoresSafeArea()
                    }
                }
            }
            .navigationTitle(Text(verbatim: "TaiwanFRP"))
            .navigationBarTitleDisplayMode(.inline)
            .logoutConfirmation(isPresented: $showingLogout)
        }
    }
}

extension View {
    func logoutConfirmation(isPresented: Binding<Bool>) -> some View {
        modifier(LogoutConfirmationModifier(isPresented: isPresented))
    }
}

private struct LogoutConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content.alert(settings.text("確認登出", "Confirm Logout"), isPresented: $isPresented) {
            Button(settings.text("登出", "Logout"), role: .destructive) {
                Task { await viewModel.logout(clearDiscordSession: false) }
            }
            Button(settings.text("登出並清除 Discord 登入", "Logout and clear Discord login"), role: .destructive) {
                Task { await viewModel.logout(clearDiscordSession: true) }
            }
            Button(settings.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(settings.text("確定要登出您的帳號嗎？", "Are you sure you want to logout?"))
        }
    }
}

struct ProfileToolbarItem: ToolbarContent {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @Binding var showingProfile: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingProfile = true
            } label: {
                UserAvatar(user: viewModel.user)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(settings.text("個人資料", "Profile"))
        }
    }
}

extension View {
    func profileToolbar(isPresented: Binding<Bool>) -> some View {
        modifier(ProfileToolbarModifier(isPresented: isPresented))
    }
}

private struct ProfileToolbarModifier: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject private var viewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(verbatim: "TaiwanFRP")
                        .font(.headline)
                }
                ProfileToolbarItem(showingProfile: $isPresented)
            }
            .sheet(isPresented: $isPresented) {
                if let user = viewModel.user {
                    ProfilePage(user: user)
                }
            }
            .onChange(of: viewModel.hasSession) { _, hasSession in
                if !hasSession { isPresented = false }
            }
    }
}

struct UserAvatar: View {
    let user: UserMeResponse?

    var body: some View {
        if let user, let discordId = user.discordId, let avatar = user.avatar,
           let url = URL(string: "https://cdn.discordapp.com/avatars/\(discordId)/\(avatar).png?size=256") {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallback
            }
            .clipShape(Circle())
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings.shared)
}
