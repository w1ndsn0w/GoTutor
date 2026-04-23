import SwiftUI

struct SidePanelContent: View {
    @ObservedObject var game: GoGameViewModel

    var body: some View {
        VStack(spacing: 20) {
            engineStatusSection

            prisonerSection

            Divider()

            if game.isTutorMode {
                tutorSection
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if (game.showRealTimeTerritory || game.isEndGameScoring), let analysis = game.currentAnalysis {
                ScoreOverlayCard(territory: analysis, capturesBlack: game.capturesBlack, capturesWhite: game.capturesWhite)
                    .background(Color.clear)
                    .shadow(radius: 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            controlsSection
            statusMessage
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var prisonerSection: some View {
        VStack(spacing: 12) {
            Text("提子信息 (Prisoners)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                PrisonerPill(isBlack: true, count: game.capturesBlack)
                Spacer()
                PrisonerPill(isBlack: false, count: game.capturesWhite)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var engineStatusSection: some View {
        if (!game.isEngineReady && game.engineStatusMessage != nil) || game.isAIThinking || game.isHintThinking || game.analysisProgress < 1.0 {
            VStack(alignment: .leading, spacing: 8) {
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
                }

                if let message = game.engineStatusMessage, !game.isEngineReady {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
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
                Text("DeepSeek 导师点评")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
            }
            Divider()

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
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
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
