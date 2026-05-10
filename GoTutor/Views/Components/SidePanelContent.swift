import SwiftUI

struct SidePanelContent: View {
    @ObservedObject var game: GoGameViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    gameSummarySection
                    engineStatusSection
                    prisonerSection

                    if game.isTutorMode {
                        tutorSection
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    if (game.showRealTimeTerritory || game.isEndGameScoring), let analysis = game.currentAnalysis {
                        ScoreOverlayCard(territory: analysis, capturesBlack: game.capturesBlack, capturesWhite: game.capturesWhite)
                            .frame(maxWidth: .infinity)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(16)
            }

            Divider()

            controlsSection
                .padding(16)

            statusMessage
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var prisonerSection: some View {
        InspectorPanel(title: "提子", systemImage: "circle.grid.2x2") {
            HStack {
                PrisonerPill(isBlack: true, count: game.capturesBlack)
                Spacer()
                PrisonerPill(isBlack: false, count: game.capturesWhite)
            }
        }
    }

    private var gameSummarySection: some View {
        InspectorPanel(title: "棋局", systemImage: "checkerboard.rectangle") {
            VStack(spacing: 10) {
                InspectorInfoRow(title: "模式", value: modeText, systemImage: "person.2")
                InspectorInfoRow(title: "当前", value: currentPlayerText, systemImage: "circle.lefthalf.filled")
                InspectorInfoRow(title: "手数", value: "\(game.moves.count)", systemImage: "number")

                if game.isAIBattleMode {
                    InspectorInfoRow(title: "AI 难度", value: game.aiDifficulty.title, systemImage: "dial.low")
                    InspectorInfoRow(title: "AI 执棋", value: game.aiPlayerColor == .black ? "黑棋" : "白棋", systemImage: "sparkles")
                }
            }
        }
    }

    private var modeText: String {
        game.isAIBattleMode ? "AI 陪练" : "本地对局"
    }

    private var currentPlayerText: String {
        if game.isGameOver { return "已结束" }
        if game.isAIThinking { return "AI 思考中" }
        if game.isHintThinking { return "计算候选点" }
        return game.currentPlayer == .black ? "黑方落子" : "白方落子"
    }

    @ViewBuilder
    private var engineStatusSection: some View {
        if (!game.isEngineReady && game.engineStatusMessage != nil) || game.isAIThinking || game.isHintThinking || game.analysisProgress < 1.0 {
            InspectorPanel(title: "引擎", systemImage: "cpu") {
                HStack(spacing: 8) {
                    if game.isAIThinking || game.isHintThinking || game.analysisProgress < 1.0 {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    Text(engineStatusTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                if let message = game.engineStatusMessage, !game.isEngineReady {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var engineStatusTitle: String {
        if game.analysisProgress < 1.0 { return "复盘批量分析中" }
        if game.isAIThinking { return "AI 正在思考下一手" }
        if game.isHintThinking { return "正在计算候选落点" }
        return "KataGo 引擎未就绪"
    }

    private var tutorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("导师点评", systemImage: "graduationcap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                Spacer()
            }

            if let msg = game.blunderMessage {
                tutorFeedback(message: msg)
            } else {
                Text(tutorIdleMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.24), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: game.blunderMessage)
    }

    private var tutorIdleMessage: String {
        if game.isAnalyzingTutor { return "等待 AI 算稳..." }
        return game.currentTurn == 0 ? "请落子，导师正在观战..." : "稳健的好棋！"
    }

    @ViewBuilder
    private func tutorFeedback(message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)

        if game.isTutorThinking || !game.tutorExplanation.isEmpty {
            Divider()
            Text(game.tutorExplanation + (game.isTutorThinking ? " ..." : ""))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .animation(.linear(duration: 0.1), value: game.tutorExplanation)
        }

        if game.previousBestMove != nil {
            Text("正确下法已在棋盘用蓝圈标出")
                .font(.system(size: 11))
                .foregroundStyle(.blue.opacity(0.8))
                .padding(.top, 4)
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { game.undo() }) { Label("悔棋", systemImage: "arrow.uturn.backward") }
                    .disabled(game.moves.isEmpty)

                Button(action: { game.pass() }) { Label("Pass", systemImage: "hand.raised") }
                    .disabled(game.isGameOver || game.isAITurn)
            }

            Button(action: { game.reset() }) { Label("重新开始", systemImage: "arrow.counterclockwise") }
        }
        .buttonStyle(CleanWhiteButtonStyle())
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let reason = game.lastIllegalReason {
            Label(reason.rawValue, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        } else if game.isEndGameScoring {
            Label("点击棋子修正死活", systemImage: "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
