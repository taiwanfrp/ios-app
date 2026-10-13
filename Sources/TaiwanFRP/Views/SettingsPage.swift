import AVFoundation
import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingProfile = false
    @State private var showingVersion = false
    @State private var showingDevelopers = false
    @State private var refreshText = ""
    @State private var isFlashlightOn = false
    @FocusState private var isRefreshFieldFocused: Bool

    var body: some View {
        Form {
            Section(settings.text("主題設定", "Theme Settings")) {
                ThemeGroup(title: settings.text("基本設定", "Basic"), themes: AppTheme.basicThemes)
                ThemeGroup(title: settings.text("深色系風格", "Dark Themes"), themes: AppTheme.darkThemes)
                ThemeGroup(title: settings.text("淺色系風格", "Light Themes"), themes: AppTheme.lightThemes)
            }
            .themedRowBackground()

            Section(settings.text("語言設定", "Language Settings")) {
                Picker(settings.text("語言設定", "Language Settings"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .themedRowBackground()

            Section {
                HStack {
                    Text(settings.text("自動更新頻率", "Refresh Interval"))
                    Spacer()
                    TextField(text: $refreshText) {
                        Text(verbatim: "60")
                    }
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($isRefreshFieldFocused)
                    .onChange(of: refreshText) { _, value in
                        let digits = value.filter(\.isNumber)
                        if digits != value { refreshText = digits }
                    }
                    Text(verbatim: "s")
                        .foregroundStyle(.secondary)
                }
                Toggle(settings.text("一次僅展開一個項目", "Single Expand Mode"), isOn: $settings.singleExpandMode)
                Toggle(settings.text("啟動時自動檢查更新", "Auto check for updates on startup"), isOn: $settings.autoCheckUpdate)
                Toggle(settings.text("開啟手電筒", "Flashlight"), isOn: Binding(
                    get: { isFlashlightOn },
                    set: { setFlashlight($0) }
                ))
            } footer: {
                Text(settings.text("自動更新頻率最少 10 秒", "Minimum refresh interval is 10 seconds"))
            }
            .themedRowBackground()

            Section {
                HStack {
                    Button {
                        showingVersion = true
                    } label: {
                        Label(settings.text("版本資訊", "Version Info"), systemImage: "info.circle")
                    }
                    Spacer()
                    Button {
                        showingDevelopers = true
                    } label: {
                        Label(settings.text("開發者資訊", "Developer Info"), systemImage: "person.2")
                    }
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppGlassBackground())
        .navigationTitle(AppTab.settings.title)
        .profileToolbar(isPresented: $showingProfile)
        .toolbar {
            if isRefreshFieldFocused {
                ToolbarItem(placement: .keyboard) {
                    Button(settings.text("完成", "Done")) {
                        isRefreshFieldFocused = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingVersion) {
            VersionInfoSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingDevelopers) {
            DeveloperInfoSheet()
                .presentationDetents([.medium])
        }
        .onAppear {
            refreshText = String(settings.refreshInterval)
        }
        .onChange(of: isRefreshFieldFocused) { _, focused in
            if !focused { commitRefreshInterval() }
        }
    }

    private func commitRefreshInterval() {
        let value = max(Int(refreshText) ?? 10, 10)
        refreshText = String(value)
        settings.refreshInterval = value
    }

    private func setFlashlight(_ isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            viewModel.errorMessage = settings.text("找不到相機閃光燈", "Flashlight not found")
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
            isFlashlightOn = isOn
        } catch {
            viewModel.errorMessage = settings.text("操作失敗：", "Operation failed: ") + error.localizedDescription
        }
    }
}

private struct ThemeGroup: View {
    let title: String
    let themes: [AppTheme]
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(themes) { theme in
                    ThemeChip(theme: theme, isSelected: settings.theme == theme) {
                        withAnimation(.smooth) { settings.theme = theme }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeChip: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if theme == .system {
                        // 左半淺色、右半深色，表示會跟隨系統切換
                        ThemeSwatch(theme: .light)
                            .mask(alignment: .leading) { Rectangle().frame(width: 22) }
                        ThemeSwatch(theme: .dark)
                            .mask(alignment: .trailing) { Rectangle().frame(width: 22) }
                    } else {
                        ThemeSwatch(theme: theme)
                    }
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                    } else {
                        Circle()
                            .strokeBorder(.separator, lineWidth: 1)
                    }
                }
                .frame(width: 44, height: 44)
                Text(verbatim: theme.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.backgroundColor ?? (theme.colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.96)))
            Circle()
                .fill(theme.accentColor)
                .padding(9)
        }
    }
}

private struct VersionInfoSheet: View {
    private enum CheckState: Equatable {
        case idle
        case checking
        case result(UpdateCheckResult)
        case failed(String)
    }

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var state: CheckState = .idle

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "info.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(verbatim: settings.text("目前版本：", "Current Version: ") + UpdateChecker.currentVersion)
                    .font(.headline)

                resultView
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await check() }
                } label: {
                    Group {
                        if state == .checking {
                            ProgressView()
                                .tint(settings.theme.onAccentColor)
                        } else {
                            Label(settings.text("檢查更新", "Check for Update"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(FilledButtonStyle(background: settings.theme.accentColor, foreground: settings.theme.onAccentColor))
                .disabled(state == .checking)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(settings.text("版本資訊", "Version Info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var resultView: some View {
        switch state {
        case .idle, .checking:
            EmptyView()
        case .result(.upToDate):
            Label(settings.text("目前已是最新版本", "App is up to date"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .result(.available(let release)):
            VStack(spacing: 8) {
                Text(verbatim: settings.text("發現新版本：", "New version: ") + release.tagName)
                    .fontWeight(.semibold)
                if let url = release.htmlURL {
                    Link(destination: url) {
                        Label(settings.text("前往查看", "View Release"), systemImage: "arrow.up.right.square")
                    }
                }
            }
        case .failed(let message):
            Text(verbatim: message)
                .foregroundStyle(.red)
        }
    }

    private func check() async {
        state = .checking
        do {
            state = .result(try await UpdateChecker.check())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct DeveloperInfoSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DeveloperLink(
                    title: settings.text("TaiwanFRP APP開發者", "TaiwanFRP APP Developer"),
                    avatar: "https://avatars.githubusercontent.com/u/126395074?v=4",
                    url: "https://github.com/lnstw"
                )
                DeveloperLink(
                    title: settings.text("TaiwanFRP 2.0 前後端開發者", "TaiwanFRP 2.0 Backend & Frontend"),
                    avatar: "https://avatars.githubusercontent.com/u/102888458?v=4",
                    url: "https://github.com/redbean0721"
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(settings.text("開發者資訊", "Developer Info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}

private struct DeveloperLink: View {
    let title: String
    let avatar: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: avatar)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.glass)
    }
}
