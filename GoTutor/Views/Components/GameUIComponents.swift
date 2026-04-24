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
        .background(Color(UIColor.secondarySystemGroupedBackground), in: Capsule())
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

struct CleanWhiteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground).opacity(isEnabled ? 1.0 : 0.6))
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(isEnabled ? 0.08 : 0.0), radius: 2, y: 1)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground).opacity(isEnabled ? 1.0 : 0.6))
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(isEnabled ? 0.06 : 0.0), radius: 1, y: 1)
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
                .background(Color(UIColor.secondarySystemGroupedBackground).opacity(configuration.isOn ? 1.0 : 0.6))
                .foregroundColor(configuration.isOn ? .accentColor : .primary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(configuration.isOn ? 0.06 : 0.0), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(configuration.isOn ? 1.0 : 0.97)
    }
}
