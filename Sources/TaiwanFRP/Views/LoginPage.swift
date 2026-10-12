import SwiftUI
import WebKit

struct WelcomePage: View {
    let onGuest: () -> Void
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingDiscordLogin = false
    @State private var loginError: String?
    @State private var isLoggingIn = false
    @State private var pendingCookie: String?

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(verbatim: "TaiwanFRP")
                .font(.system(size: 45, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
            Text(settings.text("免費內網穿透服務", "Free Intranet Penetration Service"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)

            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.red.opacity(0.15)), in: .rect(cornerRadius: 16))
                    .padding(.bottom, 16)
            }

            if isLoggingIn {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 112)
            } else {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        Button {
                            loginError = nil
                            showingDiscordLogin = true
                        } label: {
                            Label(settings.text("使用 Discord 登入", "Login with Discord"), systemImage: "person.crop.circle.badge.checkmark")
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.discordBlurple)

                        Button(action: onGuest) {
                            Text(settings.text("📊 查看節點狀態 (免登入)", "📊 View Node Status (Guest)"))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGlassBackground())
        .fullScreenCover(isPresented: $showingDiscordLogin, onDismiss: finishLogin) {
            DiscordLoginSheet(
                onLogin: { cookie in
                    pendingCookie = cookie
                    isLoggingIn = true
                    showingDiscordLogin = false
                },
                onError: { message in
                    showingDiscordLogin = false
                    loginError = message
                }
            )
        }
    }

    private func finishLogin() {
        guard let cookie = pendingCookie else { return }
        pendingCookie = nil
        Task {
            isLoggingIn = true
            loginError = await viewModel.completeLogin(with: cookie)
            isLoggingIn = false
        }
    }
}

private struct DiscordLoginSheet: View {
    let onLogin: (String) -> Void
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var isLoading = true
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            DiscordLoginWebView(
                reloadToken: reloadToken,
                isLoading: $isLoading,
                onLogin: onLogin,
                onError: onError
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .overlay(alignment: .top) {
            GlassEffectContainer {
                HStack {
                    Button {
                        reloadToken += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(settings.text("重新整理", "Refresh"))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(settings.text("關閉", "Close"))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

struct DiscordLoginWebView: UIViewRepresentable {
    let reloadToken: Int
    @Binding var isLoading: Bool
    let onLogin: (String) -> Void
    let onError: (String) -> Void
    private let loginURL = URL(string: "https://api.taiwanfrp.me/api/v1/auth/discord/login")!

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.lastReloadToken = reloadToken
        webView.load(URLRequest(url: loginURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            if webView.url == nil {
                webView.load(URLRequest(url: loginURL))
            } else {
                webView.reload()
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: DiscordLoginWebView
        var lastReloadToken = 0
        private var finished = false

        init(parent: DiscordLoginWebView) {
            self.parent = parent
        }

        private func checkLoginSuccess(at url: URL, in webView: WKWebView) {
            guard !finished,
                  let host = url.host?.lowercased(),
                  host.contains("taiwanfrp.me") else { return }

            let path = url.path
            guard path.isEmpty || path == "/" || path.contains("callback") else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.finished else { return }

                let relevant = cookies.filter { cookie in
                    let domain = cookie.domain.lowercased()
                    return domain == "taiwanfrp.me" ||
                        domain == ".taiwanfrp.me" ||
                        domain == "api.taiwanfrp.me" ||
                        domain == ".api.taiwanfrp.me"
                }
                let header = relevant.reduce(into: [String: String]()) { result, cookie in
                    result[cookie.name] = cookie.value
                }
                let cookieHeader = header.map { "\($0.key)=\($0.value)" }
                    .sorted()
                    .joined(separator: "; ")
                let hasSession = cookieHeader.localizedCaseInsensitiveContains("connect.sid") ||
                    cookieHeader.localizedCaseInsensitiveContains("session") ||
                    cookieHeader.count > 40

                guard hasSession else { return }
                self.finished = true
                DispatchQueue.main.async {
                    self.parent.onLogin(cookieHeader)
                }
            }
        }

        private func checkErrorBody(in webView: WKWebView) {
            webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
                guard let self, !self.finished,
                      let text = (result as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      text.hasPrefix("{"), text.contains("\"error\""),
                      let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                let raw = json["error"] as? String ?? L10n.text("發生未知錯誤", "An unknown error occurred")
                let message = raw.localizedCaseInsensitiveContains("Rate limit exceeded")
                    ? L10n.text("登入嘗試過於頻繁，請稍後再試", "Too many login attempts. Please try again later.")
                    : raw
                self.finished = true
                self.parent.onError(message)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            guard let url = webView.url else { return }
            checkLoginSuccess(at: url, in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            guard let url = webView.url else { return }
            checkLoginSuccess(at: url, in: webView)
            checkErrorBody(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            let nsError = error as NSError
            let networkErrors = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost
            ]
            guard !finished, nsError.domain == NSURLErrorDomain, networkErrors.contains(nsError.code) else { return }
            parent.onError(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
