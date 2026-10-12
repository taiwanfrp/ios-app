import Foundation
import WebKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif

enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, message: String? = nil)
    case missingSession

    var statusCode: Int? {
        if case .httpStatus(let status, _) = self { status } else { nil }
    }

    var serverMessage: String? {
        if case .httpStatus(_, let message) = self { message } else { nil }
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse: L10n.text("伺服器回應格式無效", "Invalid server response")
        case .httpStatus(let status, let message):
            message ?? L10n.text("伺服器錯誤（\(status)）", "Server error (\(status))")
        case .missingSession: L10n.text("尚未登入", "Not signed in")
        }
    }
}

final class SessionStore: @unchecked Sendable {
    static let shared = SessionStore()
    private let key = "com.lnstw.TaiwanFRP.loginCookie"

    var cookie: String? {
        get {
#if canImport(Security)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
#else
            return UserDefaults.standard.string(forKey: key)
#endif
        }
        set {
#if canImport(Security)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
            if let newValue, let data = newValue.data(using: .utf8) {
                var attributes = query
                attributes[kSecValueData as String] = data
                SecItemAdd(attributes as CFDictionary, nil)
            }
#else
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
#endif
        }
    }

    func clear() {
        cookie = nil
    }

    func clearTaiwanFRPAPICache() {
        URLCache.shared.removeAllCachedResponses()
    }

    @MainActor
    func clearDiscordLoginState() async {
        let websiteStore = WKWebsiteDataStore.default()
        let records = await withCheckedContinuation { continuation in
            websiteStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                continuation.resume(returning: records)
            }
        }

        let discordRecords = records.filter { record in
            let name = record.displayName.lowercased()
            return name.contains("discord.com") ||
                name.contains("discordapp.com") ||
                name.contains("discord.gg")
        }

        if !discordRecords.isEmpty {
            await withCheckedContinuation { continuation in
                websiteStore.removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    for: discordRecords
                ) {
                    continuation.resume()
                }
            }
        }

        let cookieStore = websiteStore.httpCookieStore
        let cookies = await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }

        for cookie in cookies where isDiscordDomain(cookie.domain) {
            await cookieStore.deleteCookie(cookie)
        }
    }

    private func isDiscordDomain(_ rawDomain: String) -> Bool {
        let domain = rawDomain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domain == "discord.com" ||
            domain.hasSuffix(".discord.com") ||
            domain == "discordapp.com" ||
            domain.hasSuffix(".discordapp.com") ||
            domain == "discord.gg" ||
            domain.hasSuffix(".discord.gg")
    }
}

final class TaiwanFRPAPI: @unchecked Sendable {
    static let shared = TaiwanFRPAPI()
    private let baseURL = URL(string: "https://api.taiwanfrp.me/")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private func send(
        _ path: String,
        method: String,
        body: Encodable?,
        authenticated: Bool,
        cookie explicitCookie: String? = nil
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if authenticated, let cookie = explicitCookie ?? SessionStore.shared.cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = authenticated
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode, message: Self.errorMessage(from: data))
        }
        return data
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        for key in ["detail", "error", "message"] {
            if let message = object[key] as? String, !message.isEmpty {
                return message
            }
        }
        return nil
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await send(path, method: method, body: body, authenticated: authenticated)
        return try decoder.decode(T.self, from: data)
    }

    private func perform(_ path: String, method: String, body: Encodable? = nil) async throws {
        _ = try await send(path, method: method, body: body, authenticated: true)
    }

    func user() async throws -> UserMeResponse {
        try await request("api/v1/users/me?refresh=\(UUID().uuidString)")
    }
    func nodes() async throws -> [NodeResponse] { try await request("api/v1/nodes") }
    func publicNodes() async throws -> [NodeResponse] {
        try await request("api/v1/nodes", authenticated: false)
    }
    func tunnels() async throws -> [TunnelResponse] { try await request("api/v1/tunnels") }
    func status() async throws -> SystemStatusResponse { try await request("status") }

    func becomeNodeProvider() async throws {
        try await perform("api/v1/users/me/become_node_provider", method: "POST")
    }

    func logout(cookie: String) async throws {
        _ = try await send("api/v1/auth/logout", method: "POST", body: nil, authenticated: true, cookie: cookie)
    }

    func createNode(_ node: CreateNodeRequest) async throws {
        try await perform("api/v1/nodes", method: "POST", body: node)
    }

    func createTunnel(_ tunnel: CreateTunnelRequest) async throws {
        try await perform("api/v1/tunnels", method: "POST", body: tunnel)
    }

    func updateNode(id: Int, request: NodeUpdateRequest) async throws {
        try await perform("api/v1/nodes/\(id)", method: "PATCH", body: request)
    }

    func updateTunnel(id: String, request: TunnelUpdateRequest) async throws {
        try await perform("api/v1/tunnels/\(id)", method: "PATCH", body: request)
    }

    func deleteNode(id: Int) async throws {
        try await perform("api/v1/nodes/\(id)", method: "DELETE")
    }

    func deleteTunnel(id: String) async throws {
        try await perform("api/v1/tunnels/\(id)", method: "DELETE")
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
