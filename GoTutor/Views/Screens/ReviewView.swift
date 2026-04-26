import SwiftUI

struct ReviewView: View {
    @Environment(\.dismiss) var dismiss
    let fileURL: URL
    
    // 复盘页面拥有一个独立的“大脑”
    @StateObject private var game = GoGameViewModel()

    private var phaseClassifier: GamePhaseClassifier {
        GamePhaseClassifier(
            totalMoves: game.moves.count,
            boardSize: game.size,
            moves: game.moves,
            analyses: game.moveAnalyses,
            analysisProgress: game.analysisProgress
        )
    }

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
                        
                        // 底部控制台：Slider 和 按钮完美移植
                        VStack(spacing: 12) {
                            ReviewPhaseTimeline(classifier: phaseClassifier, currentTurn: game.currentTurn)
                                .padding(.horizontal, 40)

                            HStack {
                                Text("0").font(.caption).foregroundStyle(.secondary)
                                Slider(
                                    value: Binding(
                                        get: { Double(game.currentTurn) },
                                        set: { game.setTurn(Int($0)) }
                                    ),
                                    in: 0...Double(max(1, game.moves.count)),
                                    step: 1
                                )
                                Text("\(game.moves.count)").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 40)
                            
                            HStack(spacing: 30) {
                                Button(action: { game.setTurn(0) }) { Image(systemName: "backward.end.fill").font(.title2) }.buttonStyle(.plain)
                                Button(action: { game.setTurn(max(0, game.currentTurn - 1)) }) { Image(systemName: "chevron.left.circle.fill").font(.largeTitle) }.buttonStyle(.plain).disabled(game.currentTurn == 0)
                                
                                Text("第 \(game.currentTurn) 手")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .frame(width: 100)
                                
                                Button(action: { game.setTurn(min(game.moves.count, game.currentTurn + 1)) }) { Image(systemName: "chevron.right.circle.fill").font(.largeTitle) }.buttonStyle(.plain).disabled(game.currentTurn == game.moves.count)
                                Button(action: { game.setTurn(game.moves.count) }) { Image(systemName: "forward.end.fill").font(.title2) }.buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                Divider()
                
                ReviewTeachingPanel(game: game, phaseClassifier: phaseClassifier)
            }
        }
        .onAppear {
            game.loadGame(from: fileURL)
        }
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
