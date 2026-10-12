import Foundation
import SwiftUI

enum AccountBlock: Equatable {
    case suspended
    case banned
    case deleted

    init?(status: String?) {
        switch status?.lowercased() {
        case "suspended": self = .suspended
        case "banned": self = .banned
        case "deleted": self = .deleted
        default: return nil
        }
    }

    init?(message: String?) {
        guard let message = message?.lowercased() else { return nil }
        if message.contains("suspended") {
            self = .suspended
        } else if message.contains("banned") {
            self = .banned
        } else if message.contains("deleted") {
            self = .deleted
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .suspended: L10n.text("未啟用帳號", "Account is suspended")
        case .banned: L10n.text("此帳號已被封禁", "This account has been banned")
        case .deleted: L10n.text("此帳號已刪除 請聯繫管理員", "This account has been deleted. Please contact the administrator.")
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var user: UserMeResponse?
    @Published private(set) var nodes: [NodeResponse] = []
    @Published private(set) var tunnels: [TunnelResponse] = []
    @Published private(set) var systemStatus: SystemStatusResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var hasCheckedSession = false
    @Published private(set) var hasLoadedData = false
    @Published private(set) var dataError: String?
    @Published private(set) var accountBlock: AccountBlock?
    @Published private(set) var hasSession = SessionStore.shared.cookie != nil
    @Published var errorMessage: String?
    @Published var toast: String?
    var isInForeground = true

    private var refreshTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var sessionGeneration = 0

    var isAuthenticated: Bool { user != nil }

    var canCreateNode: Bool {
        user?.permissions.contains("node.create") == true
    }

    func canManage(_ node: NodeResponse) -> Bool {
        guard let ownerId = node.ownerId, let userId = user?.id else { return false }
        return ownerId == userId
    }

    func completeLogin(with cookie: String) async -> String? {
        SessionStore.shared.cookie = cookie
        accountBlock = nil
        do {
            let latestUser = try await TaiwanFRPAPI.shared.user()
            user = latestUser
            accountBlock = AccountBlock(status: latestUser.status)
            hasSession = true
            return nil
        } catch {
            if let apiError = error as? APIError, apiError.statusCode == 403,
               let block = AccountBlock(message: apiError.serverMessage) {
                accountBlock = block
                hasSession = true
                return nil
            }
            SessionStore.shared.clear()
            if let apiError = error as? APIError, apiError.statusCode == 401 {
                return L10n.text("無法獲取使用者資訊", "Unable to get user information")
            }
            return error.localizedDescription
        }
    }

    func checkSession() async {
        defer { hasCheckedSession = true }
        guard hasSession else { return }
        await refreshCurrentUser(isAutomatic: true)
    }

    func refreshCurrentUser(isAutomatic: Bool = false) async {
        guard hasSession else {
            user = nil
            return
        }

        let generation = sessionGeneration
        do {
            let latestUser = try await TaiwanFRPAPI.shared.user()
            guard generation == sessionGeneration else { return }
            user = latestUser
            accountBlock = AccountBlock(status: latestUser.status)
        } catch {
            guard generation == sessionGeneration else { return }
            await handle(error, isAutomatic: isAutomatic)
        }
    }

    func logout(clearDiscordSession: Bool = false) async {
        guard hasSession else { return }
        let cookie = SessionStore.shared.cookie

        sessionGeneration += 1
        SessionStore.shared.clear()
        SessionStore.shared.clearTaiwanFRPAPICache()
        hasSession = false
        user = nil
        nodes = []
        tunnels = []
        systemStatus = nil
        accountBlock = nil
        hasLoadedData = false
        dataError = nil
        errorMessage = nil

        if clearDiscordSession {
            await SessionStore.shared.clearDiscordLoginState()
        }
        if let cookie {
            Task.detached {
                try? await TaiwanFRPAPI.shared.logout(cookie: cookie)
            }
        }
    }

    func refresh(includeUser: Bool = true, isAutomatic: Bool = false) async {
        while let refreshTask {
            await refreshTask.value
        }

        let task = Task { await performRefresh(includeUser: includeUser, isAutomatic: isAutomatic) }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh(includeUser: Bool, isAutomatic: Bool) async {
        guard hasSession else { return }
        let generation = sessionGeneration
        isLoading = true
        defer { isLoading = false }

        do {
            async let nodesRequest = TaiwanFRPAPI.shared.nodes()
            async let tunnelsRequest = TaiwanFRPAPI.shared.tunnels()
            async let statusRequest = TaiwanFRPAPI.shared.status()

            let (newNodes, newTunnels, newStatus) = try await (
                nodesRequest,
                tunnelsRequest,
                statusRequest
            )
            guard generation == sessionGeneration else { return }
            if includeUser {
                let latestUser = try await TaiwanFRPAPI.shared.user()
                guard generation == sessionGeneration else { return }
                user = latestUser
                accountBlock = AccountBlock(status: latestUser.status)
            }
            nodes = newNodes
            tunnels = newTunnels
            systemStatus = newStatus
            hasLoadedData = true
            dataError = nil
            errorMessage = nil
        } catch {
            guard generation == sessionGeneration else { return }
            if !isCancellationError(error), !hasLoadedData {
                dataError = error.localizedDescription
            }
            await handle(error, isAutomatic: isAutomatic)
        }
    }

    private func handle(_ error: Error, isAutomatic: Bool) async {
        guard hasSession, !isCancellationError(error) else { return }
        if let apiError = error as? APIError {
            switch apiError.statusCode {
            case 401:
                await logout()
                return
            case 403:
                if let block = AccountBlock(message: apiError.serverMessage) {
                    accountBlock = block
                    return
                }
            default:
                break
            }
        }
        guard isInForeground, !(isAutomatic && error is URLError) else { return }
        errorMessage = error.localizedDescription
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.snappy) { toast = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { toast = nil }
        }
    }

    func createNode(_ request: CreateNodeRequest) async throws {
        try await TaiwanFRPAPI.shared.createNode(request)
        showToast(L10n.text("創建成功", "Created successfully"))
        await refresh()
    }

    func updateNode(id: Int, request: NodeUpdateRequest) async throws {
        try await TaiwanFRPAPI.shared.updateNode(id: id, request: request)
        showToast(L10n.text("更新成功", "Updated successfully"))
        await refresh()
    }

    func deleteNode(_ node: NodeResponse) async {
        guard let id = node.id else { return }
        do {
            try await TaiwanFRPAPI.shared.deleteNode(id: id)
            nodes.removeAll { $0.id == id }
            showToast(L10n.text("刪除成功", "Deleted successfully"))
        } catch {
            errorMessage = L10n.text("刪除失敗：", "Delete failed: ") + error.localizedDescription
        }
    }

    func becomeNodeProvider() async {
        do {
            try await TaiwanFRPAPI.shared.becomeNodeProvider()
            showToast(L10n.text("申請成功！您現在可以建立節點了", "Application successful! You can now create nodes."))
            await refresh()
        } catch {
            errorMessage = L10n.text("申請失敗：", "Application failed: ") + error.localizedDescription
        }
    }

    func createTunnel(_ request: CreateTunnelRequest) async throws {
        try await TaiwanFRPAPI.shared.createTunnel(request)
        showToast(L10n.text("創建成功", "Created successfully"))
        await refresh()
    }

    func updateTunnel(id: String, request: TunnelUpdateRequest) async throws {
        try await TaiwanFRPAPI.shared.updateTunnel(id: id, request: request)
        showToast(L10n.text("更新成功", "Updated successfully"))
        await refresh()
    }

    func deleteTunnel(_ tunnel: TunnelResponse) async {
        guard let id = tunnel.id else { return }
        do {
            try await TaiwanFRPAPI.shared.deleteTunnel(id: id)
            tunnels.removeAll { $0.id == id }
            showToast(L10n.text("刪除成功", "Deleted successfully"))
        } catch {
            errorMessage = L10n.text("刪除失敗：", "Delete failed: ") + error.localizedDescription
        }
    }
}
