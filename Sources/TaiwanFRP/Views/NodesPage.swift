import SwiftUI

struct NodesPage: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var editorMode: NodeEditorMode?
    @State private var showingProfile = false
    @State private var isApplyingProvider = false

    var body: some View {
        NodeList(
            nodes: viewModel.nodes,
            isLoading: !viewModel.hasLoadedData && viewModel.dataError == nil,
            error: viewModel.hasLoadedData ? nil : viewModel.dataError,
            isGuest: false,
            onEdit: { editorMode = .edit($0) },
            revealsFooterOnOverscroll: true,
            isRefreshing: viewModel.isLoading
        ) {
            if !viewModel.canCreateNode, viewModel.hasLoadedData {
                Button {
                    Task {
                        isApplyingProvider = true
                        await viewModel.becomeNodeProvider()
                        isApplyingProvider = false
                    }
                } label: {
                    Group {
                        if isApplyingProvider {
                            ProgressView()
                                .tint(settings.theme.onAccentColor)
                        } else {
                            Label(settings.text("申請成為節點提供者", "Become a Node Provider"), systemImage: "server.rack")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(FilledButtonStyle(background: settings.theme.accentColor, foreground: settings.theme.onAccentColor))
                .disabled(isApplyingProvider)
                .padding(.vertical, 32)
            }
        }
        .refreshable { await viewModel.refresh() }
        .navigationTitle(AppTab.nodes.title)
        .profileToolbar(isPresented: $showingProfile)
        .toolbar {
            if viewModel.canCreateNode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(settings.text("新增節點", "Add Node"))
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            NodeEditorSheet(node: mode.node)
        }
    }
}

struct NodeList<Footer: View>: View {
    let nodes: [NodeResponse]
    let isLoading: Bool
    let error: String?
    let isGuest: Bool
    var onEdit: (NodeResponse) -> Void = { _ in }
    var revealsFooterOnOverscroll = false
    var isRefreshing = false
    @ViewBuilder var footer: () -> Footer
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var searchQuery = ""
    @State private var expandedNodeIDs = Set<Int>()
    @State private var nodeToDelete: NodeResponse?
    @State private var isFooterRevealed = false
    @State private var pendingScrollToFooter = false
    @State private var scrollPhase: ScrollPhase = .idle

    private let overscrollThreshold: CGFloat = 120
    private let footerID = "nodeListFooter"

    private var filteredNodes: [NodeResponse] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }
        return nodes.filter {
            ($0.name?.localizedCaseInsensitiveContains(query) == true) ||
            ($0.host?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            scrollContent
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                    if newPhase == .idle, pendingScrollToFooter {
                        pendingScrollToFooter = false
                        withAnimation(.smooth) {
                            proxy.scrollTo(footerID, anchor: .bottom)
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    let maxOffset = max(
                        geometry.contentSize.height + geometry.contentInsets.bottom - geometry.containerSize.height,
                        -geometry.contentInsets.top
                    )
                    return geometry.contentOffset.y - maxOffset
                } action: { _, overscroll in
                    guard revealsFooterOnOverscroll, !isFooterRevealed,
                          scrollPhase == .interacting, overscroll >= overscrollThreshold else { return }
                    withAnimation(.snappy) {
                        isFooterRevealed = true
                    }
                    pendingScrollToFooter = true
                }
        }
        .sensoryFeedback(.impact, trigger: isFooterRevealed) { _, revealed in revealed }
        .onChange(of: isRefreshing) { _, refreshing in
            if refreshing {
                isFooterRevealed = false
                pendingScrollToFooter = false
            }
        }
        .background(AppGlassBackground())
        .searchable(text: $searchQuery, prompt: settings.text("搜尋節點", "Search Nodes"))
        .alert(
            settings.text("確認刪除", "Confirm Delete"),
            isPresented: Binding(get: { nodeToDelete != nil }, set: { if !$0 { nodeToDelete = nil } }),
            presenting: nodeToDelete
        ) { node in
            Button(settings.text("刪除", "Delete"), role: .destructive) {
                Task { await viewModel.deleteNode(node) }
            }
            Button(settings.text("取消", "Cancel"), role: .cancel) {}
        } message: { node in
            Text(verbatim: deleteMessage(name: node.name, id: node.id.map(String.init)))
        }
    }

    @ViewBuilder
    private var revealableFooter: some View {
        if !revealsFooterOnOverscroll || isFooterRevealed {
            footer()
                .id(footerID)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var scrollContent: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 80)
            } else if let error {
                ContentUnavailableView(
                    settings.text("無法載入節點", "Unable to load nodes"),
                    systemImage: "wifi.exclamationmark",
                    description: Text(verbatim: error)
                )
                .padding(.top, 40)
            } else if filteredNodes.isEmpty {
                if searchQuery.isEmpty {
                    ContentUnavailableView(settings.text("目前沒有節點", "No nodes found"), systemImage: "server.rack")
                        .padding(.top, 40)
                } else {
                    ContentUnavailableView.search(text: searchQuery)
                        .padding(.top, 40)
                }
                footer()
                    .padding(.horizontal)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredNodes) { node in
                        NodeRow(
                            node: node,
                            isExpanded: node.id.map(expandedNodeIDs.contains) ?? false,
                            canManage: !isGuest && viewModel.canManage(node),
                            onToggle: { toggle(node) },
                            onEdit: { onEdit(node) },
                            onDelete: { nodeToDelete = node }
                        )
                    }
                    revealableFooter
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    private func deleteMessage(name: String?, id: String?) -> String {
        settings.text(
            "您確定要刪除「\(name ?? "")」嗎？\nID: \(id ?? "")\n\n此操作無法撤銷。",
            "Are you sure you want to delete \"\(name ?? "")\"?\nID: \(id ?? "")\n\nThis action cannot be undone."
        )
    }

    private func toggle(_ node: NodeResponse) {
        guard let id = node.id else { return }
        withAnimation(.snappy) {
            if expandedNodeIDs.contains(id) {
                expandedNodeIDs.remove(id)
            } else if settings.singleExpandMode {
                expandedNodeIDs = [id]
            } else {
                expandedNodeIDs.insert(id)
            }
        }
    }
}

extension NodeList where Footer == EmptyView {
    init(nodes: [NodeResponse], isLoading: Bool, error: String?, isGuest: Bool) {
        self.init(nodes: nodes, isLoading: isLoading, error: error, isGuest: isGuest) { EmptyView() }
    }
}

private struct NodeRow: View {
    let node: NodeResponse
    let isExpanded: Bool
    let canManage: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var settings: AppSettings

    private var onlineColor: Color {
        switch node.isOnline {
        case true?: .statusGreen
        case false?: .red
        case nil: .gray
        }
    }

    private var onlineText: String {
        switch node.isOnline {
        case true?: settings.text("上線", "Online")
        case false?: settings.text("下線", "Offline")
        case nil: settings.text("未知", "Unknown")
        }
    }

    private var operationText: String {
        switch node.status?.lowercased() {
        case "active": settings.text("可用", "Available")
        case "maintenance": settings.text("維護中", "Maintenance")
        default: settings.text("停用", "Disabled")
        }
    }

    private var operationColor: Color {
        switch node.status?.lowercased() {
        case "active": .statusGreen
        case "maintenance": Color(hex: 0x2196F3)
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(onlineColor)
                        .frame(width: 34, height: 34)
                        .background(onlineColor.opacity(0.14), in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: node.name ?? settings.text("未知", "Unknown"))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(verbatim: node.host ?? "N/A")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Text(onlineText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(onlineColor)
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
                    DetailRow(title: "ID", value: node.id.map(String.init) ?? "N/A", copyMessage: settings.text("ID 已複製", "ID copied"))
                    DetailRow(title: settings.text("運營狀態", "Operation Status"), value: operationText, valueColor: operationColor)
                    DetailRow(title: "Host", value: node.host ?? "N/A", copyMessage: settings.text("已複製 Host", "Host Copied"))
                    DetailRow(
                        title: settings.text("連接埠範圍", "Port Range"),
                        value: "\(node.portStart.map(String.init) ?? "-") - \(node.portEnd.map(String.init) ?? "-")",
                        copyMessage: settings.text("埠號已複製", "Port copied")
                    )
                    DetailRow(
                        title: settings.text("公開", "Public"),
                        value: node.isPublic == true ? settings.text("是", "Yes") : settings.text("否", "No")
                    )
                    if let description = node.description, !description.isEmpty {
                        DetailRow(title: settings.text("描述", "Description"), value: description, copyMessage: settings.text("描述已複製", "Description copied"))
                    }

                    if canManage {
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
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .contextMenu {
            if canManage {
                Button(settings.text("編輯", "Edit"), systemImage: "pencil", action: onEdit)
                Button(settings.text("刪除", "Delete"), systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }
}

private enum NodeEditorMode: Identifiable {
    case create
    case edit(NodeResponse)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let node): "edit-\(node.id.map(String.init) ?? "")"
        }
    }

    var node: NodeResponse? {
        if case .edit(let node) = self { node } else { nil }
    }
}
