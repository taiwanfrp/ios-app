import SwiftUI

struct GuestNodesPage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var nodes: [NodeResponse] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            NodeList(
                nodes: nodes,
                isLoading: !hasLoaded && errorMessage == nil,
                error: hasLoaded ? nil : errorMessage,
                isGuest: true
            )
            .refreshable { await loadNodes() }
            .navigationTitle(settings.text("節點即時狀態", "Node Status"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel(settings.text("返回", "Back"))
                }
            }
            .overlay(alignment: .bottom) {
                ToastOverlay(message: viewModel.toast)
            }
            .task {
                while !Task.isCancelled {
                    await loadNodes()
                    try? await Task.sleep(for: .seconds(settings.refreshInterval))
                }
            }
        }
    }

    private func loadNodes() async {
        do {
            nodes = try await TaiwanFRPAPI.shared.publicNodes()
            hasLoaded = true
            errorMessage = nil
        } catch {
            if !hasLoaded {
                errorMessage = error.localizedDescription
            }
        }
    }
}
