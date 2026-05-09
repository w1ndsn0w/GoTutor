import SwiftUI

struct ReviewView: View {
    @Environment(\.dismiss) var dismiss
    let fileURL: URL
    
    // 复盘页面拥有一个独立的“大脑”
    @StateObject private var game = GoGameViewModel()
    @State private var phaseClassifier = GamePhaseClassifier(totalMoves: 0, boardSize: 19)

    var body: some View {
        VStack(spacing: 0) {
            // ====================
            // 顶栏
            // ====================
            HStack {
                Button(action: { dismiss() }) {
                    Label("退出复盘", systemImage: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("复盘模式 - \(fileURL.lastPathComponent)")
                    .font(.headline)
                Spacer()
                // 占位保持居中
                Color.clear.frame(width: 100, height: 1)
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()

            HStack(spacing: 0) {
                // ====================
                // 左侧：棋盘与进度控制
                // ====================
                ZStack {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        GoBoardWithCoordinatesView(
                            game: game, hoverPoint: .constant(nil),
                            showCoordinates: true, showStarPoints: true,
                            showHoverGhost: false, showLastMoveMark: true,
                            useWoodBackground: true, territory: game.currentAnalysis
                        )
                        .padding()
                        .frame(maxWidth: 800, maxHeight: 800)
                        
                        Spacer()
                        
                        ReviewPlaybackControls(
                            currentTurn: game.currentTurn,
                            totalMoves: game.moves.count,
                            phaseClassifier: phaseClassifier,
                            onSetTurn: { game.setTurn($0) }
                        )
                        .padding(.bottom, 20)
                    }
                }
                
                Divider()
                
                ReviewTeachingPanel(
                    state: game.reviewPanelState,
                    phaseClassifier: phaseClassifier,
                    showsTerritory: $game.showRealTimeTerritory,
                    onSelectTurn: { game.setTurn($0) }
                )
            }
        }
        .onAppear {
            game.loadGame(from: fileURL)
            refreshPhaseClassifier()
        }
        .onChange(of: game.analysisProgress) { _, _ in
            refreshPhaseClassifier()
        }
    }

    private func refreshPhaseClassifier() {
        phaseClassifier = GamePhaseClassifier(
            totalMoves: game.moves.count,
            boardSize: game.size,
            moves: game.moves,
            analyses: game.moveAnalyses,
            analysisProgress: game.analysisProgress
        )
    }
}

private struct ReviewPlaybackControls: View {
    let currentTurn: Int
    let totalMoves: Int
    let phaseClassifier: GamePhaseClassifier
    let onSetTurn: (Int) -> Void

    @State private var sliderValue: Double = 0
    @State private var isScrubbing = false
    @State private var previewStrategy = ReviewScrubPreviewStrategy()

    private var displayedTurn: Int {
        if isScrubbing {
            return clampedTurn(Int(sliderValue.rounded()))
        }
        return currentTurn
    }

    var body: some View {
        VStack(spacing: 12) {
            ReviewPhaseTimeline(classifier: phaseClassifier, currentTurn: displayedTurn)
                .padding(.horizontal, 40)

            HStack {
                Text("0").font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { isScrubbing ? sliderValue : Double(currentTurn) },
                        set: { newValue in
                            let safeTurn = clampedTurn(Int(newValue.rounded()))
                            sliderValue = Double(safeTurn)
                            if isScrubbing {
                                previewTurn(safeTurn)
                            } else {
                                commitTurn(safeTurn)
                            }
                        }
                    ),
                    in: 0...Double(max(1, totalMoves)),
                    step: 1,
                    onEditingChanged: handleScrubbingChanged
                )
                Text("\(totalMoves)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            HStack(spacing: 30) {
                Button(action: { commitTurn(0) }) {
                    Image(systemName: "backward.end.fill").font(.title2)
                }
                .buttonStyle(.plain)

                Button(action: { commitTurn(max(0, currentTurn - 1)) }) {
                    Image(systemName: "chevron.left.circle.fill").font(.largeTitle)
                }
                .buttonStyle(.plain)
                .disabled(currentTurn == 0)

                Text("第 \(displayedTurn) 手")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .frame(width: 100)

                Button(action: { commitTurn(min(totalMoves, currentTurn + 1)) }) {
                    Image(systemName: "chevron.right.circle.fill").font(.largeTitle)
                }
                .buttonStyle(.plain)
                .disabled(currentTurn == totalMoves)

                Button(action: { commitTurn(totalMoves) }) {
                    Image(systemName: "forward.end.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            sliderValue = Double(currentTurn)
        }
        .onChange(of: currentTurn) { _, newValue in
            if !isScrubbing {
                sliderValue = Double(newValue)
            }
        }
    }

    private func handleScrubbingChanged(_ editing: Bool) {
        if editing {
            isScrubbing = true
            sliderValue = Double(currentTurn)
            previewStrategy.reset(startingAt: currentTurn)
            return
        }

        isScrubbing = false
        previewStrategy.reset()
        commitTurn(clampedTurn(Int(sliderValue.rounded())))
    }

    private func previewTurn(_ turn: Int) {
        guard previewStrategy.shouldPreview(turn: turn, totalMoves: totalMoves) else { return }
        onSetTurn(turn)
    }

    private func commitTurn(_ turn: Int) {
        let safeTurn = clampedTurn(turn)
        sliderValue = Double(safeTurn)
        previewStrategy.reset(startingAt: safeTurn)
        onSetTurn(safeTurn)
    }

    private func clampedTurn(_ turn: Int) -> Int {
        max(0, min(turn, totalMoves))
    }
}

private struct ReviewScrubPreviewStrategy {
    private let minimumInterval: TimeInterval
    private var lastPreviewDate: Date = .distantPast
    private var lastPreviewTurn: Int?

    init(minimumInterval: TimeInterval = 0.08) {
        self.minimumInterval = minimumInterval
    }

    mutating func shouldPreview(turn: Int, totalMoves: Int, now: Date = Date()) -> Bool {
        guard turn != lastPreviewTurn else { return false }

        if turn == 0 || turn == totalMoves || now.timeIntervalSince(lastPreviewDate) >= minimumInterval {
            recordPreview(turn: turn, date: now)
            return true
        }

        return false
    }

    mutating func reset(startingAt turn: Int? = nil) {
        lastPreviewDate = .distantPast
        lastPreviewTurn = turn
    }

    private mutating func recordPreview(turn: Int, date: Date) {
        lastPreviewTurn = turn
        lastPreviewDate = date
    }
}

private struct ReviewPhaseTimeline: View {
    let classifier: GamePhaseClassifier
    let currentTurn: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(classifier.spans) { span in
                    let isActive = classifier.phase(for: currentTurn) == span.phase
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: span.phase.iconName)
                                .font(.caption2.weight(.bold))
                            Text(span.phase.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        Text(span.turnText)
                            .font(.caption2)
                            .foregroundStyle(isActive ? span.phase.tint : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(span.phase.tint.opacity(isActive ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(span.phase.tint.opacity(isActive ? 0.65 : 0.18), lineWidth: 1))
                    .foregroundStyle(isActive ? span.phase.tint : .secondary)
                }
            }

            HStack(spacing: 8) {
                Text("当前阶段")
                    .foregroundStyle(.secondary)
                Text(classifier.phase(for: currentTurn).title)
                    .fontWeight(.semibold)
                    .foregroundStyle(classifier.phase(for: currentTurn).tint)
                Text(classifier.methodText)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(classifier.phase(for: currentTurn).subtitle)
                    .lineLimit(1)
                Spacer()
            }
            .font(.caption)
        }
    }
}
