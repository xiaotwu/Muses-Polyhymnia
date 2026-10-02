import SwiftUI

/// Settings-only action metrics. Menus, switches and selection rows keep their
/// native semantics instead of inheriting an action style from the entire Form.
extension View {
    func settingsAction(prominent: Bool = false) -> some View {
        modifier(SettingsActionStyle(prominent: prominent))
            .controlSize(.small)
            .buttonBorderShape(.capsule)
            .frame(minHeight: 30)
    }
}

struct SettingsIconButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(MusesTypography.system(size: 13, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .settingsAction()
        .frame(minWidth: 30)
        .help(title)
        .accessibilityLabel(title)
    }
}

struct SettingsInfoButton: View {
    let title: String
    let message: String
    @State private var presented = false

    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "info.circle")
                .font(MusesTypography.system(size: 13))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.fullAreaPlain)
        .help(message)
        .accessibilityLabel(tr("About \(title)", "关于\(title)"))
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(MusesTypography.headline)
                Text(message).font(MusesTypography.callout).textSelection(.enabled)
            }
            .padding(16)
            .frame(width: 310, alignment: .leading)
        }
    }
}

struct SettingsStatus: View {
    let title: String
    var symbol = "checkmark.circle"
    var color: Color = BrandColors.textSecondary

    var body: some View {
        Label(title, systemImage: symbol)
            .font(MusesTypography.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsKeycaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(MusesTypography.caption.monospaced())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: " "))
    }
}

/// A help action is a sibling of the switch, never part of its label. This
/// prevents AppKit from adopting the help button's name as the switch label.
struct SettingsExplainedToggle: View {
    let title: String
    @Binding var isOn: Bool
    let information: String
    var enabled = true

    var body: some View {
        HStack(spacing: 6) {
            Text(title).accessibilityHidden(true)
            SettingsInfoButton(title: title, message: information)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .disabled(!enabled)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Native button styles provide focus, activation, disabled and glass behavior.
private struct SettingsActionStyle: ViewModifier {
    let prominent: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.glassProminent).tint(BrandColors.accent)
        } else {
            content.buttonStyle(.glass).tint(nil)
        }
    }
}

/// The disclosure header retains native Button focus and a complete row target.
struct SettingsDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { configuration.isExpanded.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold)).frame(width: 12)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.fullAreaPlain)
            .accessibilityValue(configuration.isExpanded ? tr("Expanded", "已展开") : tr("Collapsed", "已收起"))
            if configuration.isExpanded { configuration.content.padding(.leading, 20) }
        }
    }
}
