import SwiftUI

struct ProfilePage: View {
    let user: UserMeResponse
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogout = false

    private var statusText: String {
        switch user.status?.lowercased() {
        case "active": settings.text("已啟用", "Enabled")
        case "draft": settings.text("未審核", "Under Review")
        case "suspended": settings.text("未啟用帳號", "Account is suspended")
        case "banned": settings.text("此帳號已被封禁", "This account has been banned")
        case "deleted": settings.text("此帳號已刪除", "This account has been deleted")
        default: user.status ?? settings.text("未知", "Unknown")
        }
    }

    private func yesNo(_ value: Bool?) -> String {
        value == true ? settings.text("是", "Yes") : settings.text("否", "No")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        UserAvatar(user: user)
                            .frame(width: 88, height: 88)
                            .shadow(color: .black.opacity(0.15), radius: 14, y: 7)
                        Text(verbatim: user.username ?? settings.text("未知", "Unknown"))
                            .font(.title2.bold())
                        Text(verbatim: settings.text("帳號狀態：", "Status: ") + statusText)
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassCard()

                    VStack(spacing: 0) {
                        profileRow(settings.text("Discord ID", "Discord ID"), user.discordId)
                        Divider()
                        profileRow(settings.text("電子郵件", "Email"), user.email)
                        Divider()
                        profileRow(settings.text("語言區域", "Locale"), user.locale)
                        Divider()
                        profileRow(settings.text("帳號驗證", "Verified"), yesNo(user.verified))
                        Divider()
                        profileRow(settings.text("兩步驟驗證 (MFA)", "MFA Enabled"), yesNo(user.mfaEnabled))
                    }
                    .padding(.horizontal)
                    .glassCard()

                    tagSection(settings.text("身分組", "Roles"), values: user.roles)
                    tagSection(settings.text("權限", "Permission"), values: user.permissions)

                    HStack {
                        Button(role: .destructive) {
                        } label: {
                            Label(settings.text("刪除帳號", "Delete account"), systemImage: "trash")
                        }
                        .disabled(true)
                        Spacer()
                        Button(role: .destructive) {
                            showingLogout = true
                        } label: {
                            Label(settings.text("登出帳號", "Logout"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .buttonStyle(.glass)
                    .tint(.red)
                }
                .padding()
            }
            .background(AppGlassBackground())
            .navigationTitle(settings.text("個人資料", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .logoutConfirmation(isPresented: $showingLogout)
        }
    }

    private func profileRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value ?? settings.text("無", "N/A"))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
    }

    private func tagSection(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if values.isEmpty {
                Text(settings.text("無", "N/A"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading) {
                    ForEach(values, id: \.self) { value in
                        Text(verbatim: value)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
    }
}
