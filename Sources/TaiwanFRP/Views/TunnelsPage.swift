import SwiftUI

struct TunnelsPage: View {
    static let tunnelLimit = 3

    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var editorMode: TunnelEditorMode?
    @State private var showingProfile = false
    @State private var expandedTunnelIDs = Set<String>()
    @State private var tunnelToDelete: TunnelResponse?

    private var isLimitReached: Bool {
        viewModel.tunnels.count >= Self.tunnelLimit
    }

    var body: some View {
        ScrollView {
            if !viewModel.hasLoadedData, viewModel.dataError == nil {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 80)
            } else if !viewModel.hasLoadedData, let error = viewModel.dataError {
                ContentUnavailableView(
                    settings.text("無法載入隧道", "Unable to load tunnels"),
                    systemImage: "wifi.exclamationmark",
                    description: Text(verbatim: error)
                )
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: settings.text("目前隧道數量：", "Current Tunnels: ") + "\(viewModel.tunnels.count) / \(Self.tunnelLimit)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLimitReached ? .red : Color.accentColor)
                        .padding(.horizontal, 4)

                    if viewModel.tunnels.isEmpty {
                        ContentUnavailableView {
                            Label(settings.text("無運行中隧道", "No tunnels running"), systemImage: AppTab.tunnels.icon)
                        } actions: {
                            Button {
                                editorMode = .create
                            } label: {
                                Text(settings.text("新增隧道", "Add Tunnel"))
                            }
                            .buttonStyle(FilledButtonStyle(background: settings.theme.accentColor, foreground: settings.theme.onAccentColor))
                        }
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.tunnels) { tunnel in
                                TunnelRow(
                                    tunnel: tunnel,
                                    isExpanded: tunnel.id.map(expandedTunnelIDs.contains) ?? false,
                                    onToggle: { toggle(tunnel) },
                                    onEdit: { editorMode = .edit(tunnel) },
                                    onDelete: { tunnelToDelete = tunnel }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .refreshable { await viewModel.refresh() }
        .background(AppGlassBackground())
        .navigationTitle(AppTab.tunnels.title)
        .profileToolbar(isPresented: $showingProfile)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isLimitReached || !viewModel.hasLoadedData)
                .accessibilityLabel(settings.text("新增隧道", "Add Tunnel"))
            }
        }
        .sheet(item: $editorMode) { mode in
            TunnelEditorSheet(tunnel: mode.tunnel)
        }
        .alert(
            settings.text("確認刪除", "Confirm Delete"),
            isPresented: Binding(get: { tunnelToDelete != nil }, set: { if !$0 { tunnelToDelete = nil } }),
            presenting: tunnelToDelete
        ) { tunnel in
            Button(settings.text("刪除", "Delete"), role: .destructive) {
                Task { await viewModel.deleteTunnel(tunnel) }
            }
            Button(settings.text("取消", "Cancel"), role: .cancel) {}
        } message: { tunnel in
            Text(verbatim: settings.text(
                "您確定要刪除「\(tunnel.name ?? "")」嗎？\nID: \(tunnel.id ?? "")\n\n此操作無法撤銷。",
                "Are you sure you want to delete \"\(tunnel.name ?? "")\"?\nID: \(tunnel.id ?? "")\n\nThis action cannot be undone."
            ))
        }
    }

    private func toggle(_ tunnel: TunnelResponse) {
        guard let id = tunnel.id else { return }
        withAnimation(.snappy) {
            if expandedTunnelIDs.contains(id) {
                expandedTunnelIDs.remove(id)
            } else if settings.singleExpandMode {
                expandedTunnelIDs = [id]
            } else {
                expandedTunnelIDs.insert(id)
            }
        }
    }
}

private struct TunnelRow: View {
    let tunnel: TunnelResponse
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var settings: AppSettings

    private var statusColor: Color {
        tunnel.status == "active" ? .statusGreen : .gray
    }

    private var statusText: String {
        switch tunnel.status {
        case "active": settings.text("運行中", "Active")
        case "draft": settings.text("未審核", "Under Review")
        default: settings.text("未運行", "Inactive")
        }
    }

    private var localAddress: String {
        "\(tunnel.localIP ?? "-"):\(tunnel.localPort.map(String.init) ?? "-")"
    }

    private func enabledText(_ value: Bool?) -> String {
        value == true ? settings.text("已啟用", "Enabled") : settings.text("已停用", "Disabled")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: AppTab.tunnels.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 34, height: 34)
                        .background(statusColor.opacity(0.14), in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: tunnel.name ?? settings.text("未知", "Unknown"))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(verbatim: localAddress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tunnel.status == "active" ? Color.statusGreen : .red)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.vertical, 12)
                VStack(spacing: 2) {
                    DetailRow(title: "ID", value: tunnel.id ?? "N/A", copyMessage: settings.text("ID 已複製", "ID copied"))
                    DetailRow(title: settings.text("通訊協定", "Protocol"), value: tunnel.protocolName ?? "N/A", copyMessage: settings.text("協議已複製", "Protocol copied"))
                    DetailRow(title: settings.text("本地", "Local"), value: localAddress, copyMessage: settings.text("本機資訊已複製", "Local info copied"))
                    DetailRow(
                        title: settings.text("遠端連接埠", "Remote Port"),
                        value: tunnel.remotePort.map(String.init) ?? "Auto",
                        copyMessage: settings.text("埠號已複製", "Port copied")
                    )
                    DetailRow(title: "KCP", value: enabledText(tunnel.isKCPEnabled))
                    DetailRow(title: "Proxy v2", value: enabledText(tunnel.isProxyProtocolV2Enabled))
                    if let description = tunnel.description, !description.isEmpty {
                        DetailRow(title: settings.text("描述", "Description"), value: description, copyMessage: settings.text("描述已複製", "Description copied"))
                    }

                    HStack {
                        Spacer()
                        Button(action: onEdit) {
                            Label(settings.text("編輯", "Edit"), systemImage: "pencil")
                        }
                        .buttonStyle(.glass)
                        Button(role: .destructive, action: onDelete) {
                            Label(settings.text("刪除", "Delete"), systemImage: "trash")
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .contextMenu {
            Button(settings.text("編輯", "Edit"), systemImage: "pencil", action: onEdit)
            Button(settings.text("刪除", "Delete"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

private enum TunnelEditorMode: Identifiable {
    case create
    case edit(TunnelResponse)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let tunnel): "edit-\(tunnel.id ?? "")"
        }
    }

    var tunnel: TunnelResponse? {
        if case .edit(let tunnel) = self { tunnel } else { nil }
    }
}
