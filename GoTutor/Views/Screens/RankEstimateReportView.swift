import SwiftUI

struct RankEstimateReportView: View {
    @ObservedObject var game: GoGameViewModel
    var onSelectTurn: ((Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var targetPlayer: Stone = .black

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                targetPicker
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)

                Divider()

                content
            }
            .navigationTitle("棋力测评报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        game.cancelRankEstimation()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        game.startRankEstimation(targetPlayer: targetPlayer)
                    } label: {
                        Label("重新测评", systemImage: "arrow.clockwise")
                    }
                    .disabled(game.moves.isEmpty)
                }
            }
        }
        .task(id: targetPlayer) {
            game.startRankEstimation(targetPlayer: targetPlayer)
        }
    }

    private var targetPicker: some View {
        HStack(spacing: 12) {
            Label("测评对象", systemImage: "person.text.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("测评对象", selection: $targetPlayer) {
                Text("黑棋").tag(Stone.black)
                Text("白棋").tag(Stone.white)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            Text("基于本局棋谱初步估计")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch game.rankEstimateState {
        case .idle:
            ProgressStateView(title: "准备测评", message: "正在等待分析任务启动...", progress: 0.0)
        case .running(let progress, let message):
            ProgressStateView(title: "正在测评", message: message, progress: progress)
        case .failed(let message):
            ErrorStateView(message: message) {
                game.startRankEstimation(targetPlayer: targetPlayer)
            }
        case .completed(let report):
            reportContent(report)
        }
    }

    private func reportContent(_ report: RankEstimateReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                estimateSummary(report)
                phaseSection(report.phaseBreakdown)
                weaknessSection(report.mistakeBreakdown)
                keyMistakesSection(report.keyMistakes)
                recommendationsSection(report)
                disclaimerSection(report)
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func estimateSummary(_ report: RankEstimateReport) -> some View {
        ReportCard(title: "估计棋力", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                SummaryMetricRow(title: "棋力区间", value: report.estimatedRange, systemImage: "target")
                SummaryMetricRow(title: "最接近棋力档", value: report.mostSimilarProfile ?? "不可用", systemImage: "person.crop.circle.badge.questionmark")
                SummaryMetricRow(title: "置信度", value: report.confidence.rawValue, systemImage: "gauge.with.dots.needle.50percent")

                Text(report.confidenceReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(report.humanSLMessage)
                    .font(.footnote)
                    .foregroundStyle(report.usedHumanSL ? .green : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !report.profileScores.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("棋力档相似度")
                            .font(.system(size: 13, weight: .bold))
                        ForEach(report.profileScores.prefix(5)) { score in
                            HStack {
                                Text(RankEstimateAnalyzer.profileDisplayName(score.profile))
                                    .font(.system(size: 13, weight: .medium))
                                ProgressView(value: score.similarityScore, total: 1.0)
                                Text("\(Int(score.similarityScore * 100))")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func phaseSection(_ phaseBreakdown: PhaseBreakdown) -> some View {
        ReportCard(title: "本局表现", systemImage: "rectangle.3.group") {
            VStack(spacing: 10) {
                PhaseSummaryRow(summary: phaseBreakdown.opening)
                PhaseSummaryRow(summary: phaseBreakdown.middleGame)
                PhaseSummaryRow(summary: phaseBreakdown.endgame)
            }
        }
    }

    private func weaknessSection(_ mistakes: [MistakeBreakdown]) -> some View {
        ReportCard(title: "主要问题", systemImage: "exclamationmark.magnifyingglass") {
            if mistakes.isEmpty {
                Text("本局没有稳定识别出主要短板，建议多盘测评后综合判断。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(mistakes) { mistake in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mistake.type.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(mistake.count) 次")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text(mistake.explanation)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func keyMistakesSection(_ mistakes: [KeyMistake]) -> some View {
        ReportCard(title: "关键问题手", systemImage: "scope") {
            if mistakes.isEmpty {
                Text("暂未识别出明显问题手。若棋谱较短或分析样本不足，可多下一盘后再测。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(mistakes) { mistake in
                        KeyMistakeRow(mistake: mistake, onSelect: onSelectTurn.map { callback in
                            { callback(mistake.turn); dismiss() }
                        })
                    }
                }
            }
        }
    }

    private func recommendationsSection(_ report: RankEstimateReport) -> some View {
        ReportCard(title: "下一步训练建议", systemImage: "figure.mind.and.body") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.recommendations, id: \.self) { recommendation in
                    Label(recommendation, systemImage: "checkmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func disclaimerSection(_ report: RankEstimateReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.disclaimer)
            Text("生成时间：\(report.generatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

private struct ProgressStateView: View {
    let title: String
    let message: String
    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: min(1.0, max(0.0, progress)), total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 260)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

private struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("测评失败")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(action: onRetry) {
                Label("重试", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

private struct ReportCard<Content: View>: View {
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
                .font(.system(size: 15, weight: .bold))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }
}

private struct SummaryMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
        }
        .font(.system(size: 14))
    }
}

private struct PhaseSummaryRow: View {
    let summary: RankPhaseSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title)
                    .font(.system(size: 14, weight: .bold))
                Text(summary.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "均损 %.1f", summary.averageScoreLoss))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text("明显问题 \(summary.majorMistakeCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct KeyMistakeRow: View {
    let mistake: KeyMistake
    let onSelect: (() -> Void)?

    var body: some View {
        Button(action: { onSelect?() }) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("第 \(mistake.turn) 手")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text(mistake.mistakeType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if onSelect != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 10) {
                    Text("实战 \(mistake.playedMove)")
                    if let recommendedMove = mistake.recommendedMove {
                        Text("推荐 \(recommendedMove)")
                    }
                    Text(String(format: "损失 %.1f 目 / %.1f%%", mistake.scoreDrop, mistake.winrateDrop * 100))
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

                Text(mistake.shortReason)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }
}
