import SwiftUI

private struct EditorToolbar: ToolbarContent {
    let canSave: Bool
    let isSaving: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(settings.text("取消", "Cancel"))
        }
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
            } else {
                Button(role: .confirm, action: onSave) {
                    Image(systemName: "checkmark")
                }
                .disabled(!canSave)
                .accessibilityLabel(settings.text("確定", "Confirm"))
            }
        }
    }
}

@MainActor
private func requiredFooter(_ show: Bool, _ settings: AppSettings) -> some View {
    Group {
        if show {
            Text(settings.text("此欄位為必填", "This field is required"))
                .foregroundStyle(.red)
        }
    }
}

struct NodeEditorSheet: View {
    let node: NodeResponse?
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var host: String
    @State private var portStart: String
    @State private var portEnd: String
    @State private var isPublic: Bool
    @State private var showErrors = false
    @State private var isSaving = false
    @State private var error: String?

    init(node: NodeResponse?) {
        self.node = node
        _name = State(initialValue: node?.name ?? "")
        _description = State(initialValue: node?.description ?? "")
        _host = State(initialValue: node?.host ?? "")
        _portStart = State(initialValue: node?.portStart.map(String.init) ?? "")
        _portEnd = State(initialValue: node?.portEnd.map(String.init) ?? "")
        _isPublic = State(initialValue: node?.isPublic ?? true)
    }

    private var isChanged: Bool {
        guard let node else { return true }
        return name != (node.name ?? "") ||
            description != (node.description ?? "") ||
            host != (node.host ?? "") ||
            portStart != (node.portStart.map(String.init) ?? "") ||
            portEnd != (node.portEnd.map(String.init) ?? "") ||
            isPublic != (node.isPublic ?? true)
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(settings.text("名稱", "Name"), text: $name)
                } footer: {
                    requiredFooter(showErrors && isBlank(name), settings)
                }
                .themedRowBackground()
                Section {
                    TextField(settings.text("描述", "Description"), text: $description, axis: .vertical)
                }
                .themedRowBackground()
                Section {
                    TextField(settings.text("主機 (Host)", "Host"), text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } footer: {
                    requiredFooter(showErrors && isBlank(host), settings)
                }
                .themedRowBackground()
                Section {
                    TextField(settings.text("起始埠號", "Start Port"), text: $portStart)
                        .keyboardType(.numberPad)
                    TextField(settings.text("結束埠號", "End Port"), text: $portEnd)
                        .keyboardType(.numberPad)
                } footer: {
                    requiredFooter(showErrors && (isBlank(portStart) || isBlank(portEnd)), settings)
                }
                .themedRowBackground()
                Section {
                    Toggle(settings.text("是否公開", "Public"), isOn: $isPublic)
                }
                .themedRowBackground()
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .themedRowBackground()
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppGlassBackground())
            .navigationTitle(node == nil ? settings.text("創建節點", "Create Node") : settings.text("編輯節點", "Edit Node"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditorToolbar(canSave: isChanged, isSaving: isSaving, onSave: save)
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() {
        guard !isBlank(name), !isBlank(host), !isBlank(portStart), !isBlank(portEnd) else {
            showErrors = true
            return
        }
        guard let start = Int(portStart), let end = Int(portEnd),
              (1...65535).contains(start), (1...65535).contains(end), start <= end else {
            error = settings.text("請輸入有效的埠號範圍（1-65535）", "Please enter a valid port range (1-65535)")
            return
        }

        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            do {
                if let node, let id = node.id {
                    try await viewModel.updateNode(id: id, request: NodeUpdateRequest(
                        status: node.status,
                        isPublic: isPublic,
                        name: name,
                        description: description,
                        host: host,
                        portStart: start,
                        portEnd: end
                    ))
                } else {
                    try await viewModel.createNode(CreateNodeRequest(
                        name: name,
                        description: description,
                        host: host,
                        portStart: start,
                        portEnd: end,
                        isPublic: isPublic
                    ))
                }
                dismiss()
            } catch {
                let prefix = node == nil ? settings.text("創建失敗：", "Creation failed: ") : settings.text("更新失敗：", "Update failed: ")
                self.error = prefix + error.localizedDescription
            }
        }
    }
}

struct TunnelEditorSheet: View {
    let tunnel: TunnelResponse?
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var nodeId: Int?
    @State private var protocolName: String
    @State private var localIP: String
    @State private var localPort: String
    @State private var remotePort: String
    @State private var kcp: Bool
    @State private var proxyV2: Bool
    @State private var showErrors = false
    @State private var remotePortInUse = false
    @State private var isSaving = false
    @State private var error: String?

    init(tunnel: TunnelResponse?) {
        self.tunnel = tunnel
        _name = State(initialValue: tunnel?.name ?? "")
        _description = State(initialValue: tunnel?.description ?? "")
        _nodeId = State(initialValue: tunnel?.nodeId)
        _protocolName = State(initialValue: tunnel?.protocolName?.lowercased() ?? "tcp")
        _localIP = State(initialValue: tunnel?.localIP ?? "127.0.0.1")
        _localPort = State(initialValue: tunnel?.localPort.map(String.init) ?? "")
        _remotePort = State(initialValue: tunnel?.remotePort.map(String.init) ?? "")
        _kcp = State(initialValue: tunnel?.isKCPEnabled ?? true)
        _proxyV2 = State(initialValue: tunnel?.isProxyProtocolV2Enabled ?? false)
    }

    private var availableNodes: [NodeResponse] {
        viewModel.nodes.filter { $0.status?.lowercased() == "active" || ($0.id != nil && $0.id == tunnel?.nodeId) }
    }

    private var protocols: [String] {
        let base = ["tcp", "udp"]
        return base.contains(protocolName) ? base : base + [protocolName]
    }

    private var selectedNode: NodeResponse? {
        availableNodes.first { $0.id == nodeId }
    }

    private var selectedNodePortRange: ClosedRange<Int>? {
        guard let start = selectedNode?.portStart,
              let end = selectedNode?.portEnd,
              (1...65535).contains(start),
              (1...65535).contains(end),
              start <= end else {
            return nil
        }
        return start...end
    }

    private var isChanged: Bool {
        guard let tunnel else { return true }
        return name != (tunnel.name ?? "") ||
            description != (tunnel.description ?? "") ||
            nodeId != tunnel.nodeId ||
            protocolName != (tunnel.protocolName?.lowercased() ?? "tcp") ||
            localIP != (tunnel.localIP ?? "127.0.0.1") ||
            localPort != (tunnel.localPort.map(String.init) ?? "") ||
            remotePort != (tunnel.remotePort.map(String.init) ?? "") ||
            kcp != (tunnel.isKCPEnabled ?? false) ||
            proxyV2 != (tunnel.isProxyProtocolV2Enabled ?? false)
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func nodeLabel(_ node: NodeResponse) -> String {
        "\(node.name ?? settings.text("未知", "Unknown")) | ID: \(node.id.map(String.init) ?? "-")"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(settings.text("名稱", "Name"), text: $name)
                } footer: {
                    requiredFooter(showErrors && isBlank(name), settings)
                }
                .themedRowBackground()
                Section {
                    TextField(settings.text("描述", "Description"), text: $description, axis: .vertical)
                }
                .themedRowBackground()

                Section {
                    Picker(selection: $nodeId) {
                        Text(settings.text("請選擇一個節點", "Please select a node")).tag(nil as Int?)
                        ForEach(availableNodes) { node in
                            VStack(alignment: .leading) {
                                Text(verbatim: nodeLabel(node))
                                Text(verbatim: "Host: \(node.host ?? "-")")
                            }
                            .tag(node.id as Int?)
                        }
                    } label: {
                        Text(settings.text("選擇節點", "Select Node"))
                    }
                    .pickerStyle(.navigationLink)

                    Picker(settings.text("傳輸協議", "Protocol"), selection: $protocolName) {
                        ForEach(protocols, id: \.self) { value in
                            Text(verbatim: value.uppercased()).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if showErrors && nodeId == nil {
                        Text(settings.text("請選擇一個項目", "Please select an item"))
                            .foregroundStyle(.red)
                    } else if availableNodes.isEmpty {
                        Text(settings.text("目前沒有可用的營運節點", "No active nodes available"))
                    }
                }
                .themedRowBackground()

                Section {
                    TextField(settings.text("本機 IP", "Local IP"), text: $localIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                    TextField(settings.text("本機埠號", "Local Port"), text: $localPort)
                        .keyboardType(.numberPad)
                } footer: {
                    requiredFooter(showErrors && (isBlank(localIP) || isBlank(localPort)), settings)
                }
                .themedRowBackground()

                Section {
                    HStack {
                        TextField(text: $remotePort) {
                            Text(settings.text("遠端埠號", "Remote Port"))
                        }
                        .keyboardType(.numberPad)
                        .onChange(of: remotePort) { remotePortInUse = false }

                        Button {
                            if let range = selectedNodePortRange {
                                remotePort = String(Int.random(in: range))
                            }
                        } label: {
                            Image(systemName: "shuffle")
                        }
                        .buttonStyle(.glass)
                        .disabled(selectedNodePortRange == nil)
                        .accessibilityLabel(settings.text("隨機選取", "Random Select"))
                    }
                } footer: {
                    if remotePortInUse {
                        Text(settings.text("此連接埠已被占用", "This port is already in use"))
                            .foregroundStyle(.red)
                    } else if showErrors && isBlank(remotePort) {
                        Text(settings.text("此欄位為必填", "This field is required"))
                            .foregroundStyle(.red)
                    } else if let range = selectedNodePortRange {
                        Text(verbatim: settings.text("範圍：", "Range: ") + "\(range.lowerBound) - \(range.upperBound)")
                    }
                }
                .themedRowBackground()

                Section {
                    Toggle("KCP", isOn: $kcp)
                    Toggle("Proxy v2", isOn: $proxyV2)
                }
                .themedRowBackground()

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .themedRowBackground()
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppGlassBackground())
            .navigationTitle(tunnel == nil ? settings.text("創建隧道", "Create Tunnel") : settings.text("編輯隧道", "Edit Tunnel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditorToolbar(canSave: isChanged, isSaving: isSaving, onSave: save)
            }
            .interactiveDismissDisabled(isSaving)
            .onChange(of: nodeId) {
                remotePortInUse = false
            }
        }
    }

    private func save() {
        guard !isBlank(name), let nodeId, !isBlank(localIP), !isBlank(localPort), !isBlank(remotePort) else {
            showErrors = true
            return
        }
        guard let local = Int(localPort.trimmingCharacters(in: .whitespaces)), (1...65535).contains(local) else {
            error = settings.text("請輸入有效的本機埠號", "Please enter a valid local port")
            return
        }
        guard let remote = Int(remotePort.trimmingCharacters(in: .whitespaces)) else {
            error = settings.text("請輸入有效的遠端埠號", "Please enter a valid remote port")
            return
        }
        if let range = selectedNodePortRange, !range.contains(remote) {
            error = settings.text("遠端埠號必須在 ", "Remote port must be within ") + "\(range.lowerBound)-\(range.upperBound)"
            return
        }

        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            do {
                if let tunnel, let id = tunnel.id {
                    try await viewModel.updateTunnel(id: id, request: TunnelUpdateRequest(
                        name: name,
                        description: description,
                        nodeId: nodeId,
                        protocolName: protocolName,
                        localIP: localIP,
                        localPort: local,
                        remotePort: remote,
                        isKCPEnabled: kcp,
                        isProxyProtocolV2Enabled: proxyV2,
                        isEnabled: nil
                    ))
                } else {
                    try await viewModel.createTunnel(CreateTunnelRequest(
                        name: name,
                        description: description,
                        nodeId: nodeId,
                        protocolName: protocolName,
                        localIP: localIP,
                        localPort: local,
                        remotePort: remote,
                        isKCPEnabled: kcp,
                        isProxyProtocolV2Enabled: proxyV2
                    ))
                }
                dismiss()
            } catch {
                if error.localizedDescription.localizedCaseInsensitiveContains("remote_port is already in use") {
                    remotePortInUse = true
                } else {
                    let prefix = tunnel == nil ? settings.text("創建失敗：", "Creation failed: ") : settings.text("更新失敗：", "Update failed: ")
                    self.error = prefix + error.localizedDescription
                }
            }
        }
    }
}
