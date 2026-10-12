import SwiftUI
import UIKit

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var interactive = false
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let surface = settings.theme.surfaceColor {
            glass = glass.tint(surface)
        }
        return interactive ? glass.interactive() : glass
    }
}

struct ThemedRowBackground: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        if let surface = settings.theme.surfaceColor {
            content.listRowBackground(surface)
        } else {
            content
        }
    }
}

extension View {
    func themedRowBackground() -> some View {
        modifier(ThemedRowBackground())
    }

    func glassCard(cornerRadius: CGFloat = 20, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

struct FilledButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(background, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppGlassBackground: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            if let background = settings.theme.backgroundColor {
                background
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
            if settings.theme.showsGlow {
                Circle()
                    .fill(settings.theme.accentColor.opacity(0.24))
                    .frame(width: 280)
                    .blur(radius: 70)
                    .offset(x: -150, y: -280)
                Circle()
                    .fill(settings.theme.secondaryColor.opacity(0.16))
                    .frame(width: 240)
                    .blur(radius: 75)
                    .offset(x: 160, y: 180)
            }
        }
        .ignoresSafeArea()
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var copyMessage: String? = nil
    var valueColor: Color? = nil
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var copied = false

    var body: some View {
        if let copyMessage {
            Button {
                UIPasteboard.general.string = value
                copied.toggle()
                viewModel.showToast(copyMessage)
            } label: {
                content(copyable: true)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: copied)
        } else {
            content(copyable: false)
        }
    }

    private func content(copyable: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.subheadline.weight(valueColor == nil ? .regular : .semibold))
                    .foregroundStyle(valueColor ?? .primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if copyable {
                Image(systemName: "doc.on.doc")
                    .font(.footnote)
                    .foregroundStyle(.tint.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

struct ToastOverlay: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

enum Links {
    static let website = URL(string: "https://taiwanfrp.me")!
    static let discord = URL(string: "https://discord.gg/ueGFVVHp85")!
    static let github = URL(string: "https://github.com/TaiwanFRP")!
}

extension Color {
    static let discordBlurple = Color(hex: 0x5865F2)
    static let statusGreen = Color(hex: 0x008000)
}
