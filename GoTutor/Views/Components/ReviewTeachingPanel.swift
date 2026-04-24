import SwiftUI

struct ReviewTeachingPanel: View {
    @ObservedObject var game: GoGameViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                analysisProgress
                currentPositionEvaluation
                currentTeachingFeedback
                keyMistakes
                territoryToggle
            }
            .padding(18)
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
    }

    private var analysisProgress: some View {
        VStack(spacing: 8) {
            if game.analysisProgress < 1.0 {
                ProgressView("AI 正在批量分析...", value: game.analysisProgress, total: 1.0)
                    .progressViewStyle(.linear)
            } else {
                Label("全盘分析完毕", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var currentPositionEvaluation: some View {
        if let analysis = game.moveAnalyses[game.currentTurn] {
            let bWin = analysis.winrate * 100
            let wWin = 100.0 - bWin
            let lead = analysis.scoreLead
            let leadStr = lead > 0 ? String(format: "黑领先 %.1f 目", lead) : String(format: "白领先 %.1f 目", abs(lead))

            VStack(alignment: .leading, spacing: 14) {
                Text("当前局面评估")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    HStack {
                        Text("黑棋").bold()
                        Spacer()
                        Text(String(format: "%.1f%%", bWin))
                            .font(.system(.body, design: .monospaced))
                    }
                    ProgressView(value: bWin, total: 100)
                        .tint(.black)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    HStack {
                        Text("白棋").bold()
                        Spacer()
                        Text(String(format: "%.1f%%", wWin))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Text(leadStr)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(lead > 0 ? Color.primary.opacity(0.1) : Color(UIColor.tertiarySystemFill), in: Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(spacing: 10) {
                ProgressView()
                Text("分析数据加载中...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var currentTeachingFeedback: some View {
        if game.currentTurn == 0 {
            teachingPlaceholder("移动到某一步后，这里会解释本手的教学价值。")
        } else if let feedback = game.teachingFeedback(for: game.currentTurn) {
            TeachingFeedbackCard(feedback: feedback, boardSize: game.size)
        } else {
            teachingPlaceholder("这一手还缺少前后局面分析，等待批量分析完成后会自动生成反馈。")
        }
    }

    private var keyMistakes: some View {
        let feedbacks = game.keyTeachingFeedbacks()

        return VStack(alignment: .leading, spacing: 12) {
            Text("本局关键失误")
                .font(.headline)

            if feedbacks.isEmpty {
                Text(game.analysisProgress < 1.0 ? "分析完成后会列出最值得复盘的手。" : "目前没有明显失误手。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(feedbacks) { feedback in
                    Button(action: { game.setTurn(feedback.turn) }) {
                        HStack(spacing: 10) {
                            Text("\(feedback.turn)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 34, height: 28)
                                .background(severityColor(feedback.severity).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(feedback.severity.rawValue) · \(feedback.category.rawValue)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("损失 \(String(format: "%.1f%%", feedback.winrateDrop * 100))，实战 \(feedback.playedMove)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var territoryToggle: some View {
        Toggle("显示地盘归属", isOn: $game.showRealTimeTerritory)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func teachingPlaceholder(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本手教学反馈")
                .font(.headline)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TeachingFeedbackCard: View {
    let feedback: TeachingFeedback
    let boardSize: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(feedback.turn) 手 · \(feedback.player == .black ? "黑棋" : "白棋")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(feedback.severity.rawValue) · \(feedback.category.rawValue)")
                        .font(.headline)
                }
                Spacer()
                Text(feedback.playedMove)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(severityColor(feedback.severity).opacity(0.16), in: Capsule())
            }

            Text(feedback.summary)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("更好的思路")
                    .font(.system(size: 13, weight: .bold))
                Text(feedback.betterMoveReason)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            if let bestMove = feedback.bestMove {
                Label("推荐点：\(bestMove)", systemImage: "scope")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("下次检查清单")
                    .font(.system(size: 13, weight: .bold))
                ForEach(feedback.checklist, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(severityColor(feedback.severity))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(severityColor(feedback.severity).opacity(0.25), lineWidth: 1))
    }
}

private func severityColor(_ severity: MistakeSeverity) -> Color {
    switch severity {
    case .solid: return .green
    case .slight: return .blue
    case .inaccuracy: return .orange
    case .mistake: return .red
    case .blunder: return .purple
    }
}
