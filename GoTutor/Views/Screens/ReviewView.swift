import SwiftUI

struct ReviewView: View {
    @Environment(\.dismiss) var dismiss
    let fileURL: URL
    
    // 复盘页面拥有一个独立的“大脑”
    @StateObject private var game = GoGameViewModel()

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
                
                ReviewTeachingPanel(game: game)
            }
        }
        .onAppear {
            // 界面出现时，立刻启动引擎并读取本地 JSON 棋谱
            game.startEngine()
            // 稍微延迟 1 秒，等待 C++ 引擎的 pipe 通道彻底建立后再发送大批量数据
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                game.loadGame(from: fileURL)
            }
        }
    }
}
