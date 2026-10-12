import Foundation

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case htmlURL = "html_url"
    }

    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case available(GitHubRelease)
}

enum UpdateChecker {
    static let repository = "TaiwanFRP/ios-app"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func check() async throws -> UpdateCheckResult {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 404 {
                throw APIError.httpStatus(404, message: L10n.text("目前還沒有發佈的 iOS 版本", "No iOS release has been published yet"))
            }
            throw APIError.httpStatus(http.statusCode)
        }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return isNewer(release.version, than: currentVersion) ? .available(release) : .upToDate
    }

    static func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(latestParts.count, currentParts.count) {
            let l = index < latestParts.count ? latestParts[index] : 0
            let c = index < currentParts.count ? currentParts[index] : 0
            if l != c { return l > c }
        }
        return false
    }
}
