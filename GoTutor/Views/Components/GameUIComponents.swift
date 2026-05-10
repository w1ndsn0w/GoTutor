import SwiftUI

struct PrisonerPill: View {
    let isBlack: Bool
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isBlack ? Color.black : Color.white)
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                .frame(width: 10, height: 10)
            Text("\(count) 子")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(UIColor.tertiarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

struct ScoreOverlayCard: View {
    let territory: TerritoryAnalysis
    let capturesBlack: Int
    let capturesWhite: Int

    private var blackScore: Int {
        territory.blackTerritory.count + capturesBlack + territory.deadWhiteStones
    }

    private var whiteScore: Int {
        territory.whiteTerritory.count + capturesWhite + territory.deadBlackStones
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前估算 (数目法)")
                .font(.system(size: 13, weight: .semibold))
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("黑方总计"); Spacer(); Text("\(blackScore) 目").bold() }
                HStack { Text("白方总计"); Spacer(); Text("\(whiteScore) 目").bold() }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("盘面黑地"); Spacer(); Text("\(territory.blackTerritory.count)") }
                HStack { Text("盘面白地"); Spacer(); Text("\(territory.whiteTerritory.count)") }
                HStack { Text("黑提白子"); Spacer(); Text("\(capturesBlack) (+\(territory.deadWhiteStones) 死子)") }
                HStack { Text("白提黑子"); Spacer(); Text("\(capturesWhite) (+\(territory.deadBlackStones) 死子)") }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
        .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.16), lineWidth: 1))
    }
}

struct CleanWhiteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .font(.system(size: 15, weight: .semibold))
            .padding(.vertical, 11)
            .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(isEnabled ? 1.0 : 0.55))
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct HeaderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(isEnabled ? 1.0 : 0.55))
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.14), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

struct CleanWhiteToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(configuration.isOn ? 1.0 : 0.55))
                .foregroundStyle(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(configuration.isOn ? 1.0 : 0.97)
    }
}

struct InspectorPanel<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }
}

struct InspectorInfoRow: View {
    let title: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}
