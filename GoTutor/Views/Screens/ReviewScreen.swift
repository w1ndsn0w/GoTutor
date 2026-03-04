import SwiftUI

struct ReviewScreen: View {
    @Environment(\.dismiss) var dismiss
    let fileURL: URL
    
    // 复盘页面拥有一个独立的“大脑”
    @StateObject private var game = GoGame()

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
                
                // ====================
                // 右侧：AI 胜率分析与雷达面板
                // ====================
                VStack(spacing: 30) {
                    // 1. AI 批量分析进度条
                    VStack(spacing: 8) {
                        if game.analysisProgress < 1.0 {
                            ProgressView("AI 正在批量分析...", value: game.analysisProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .padding(.horizontal)
                        } else {
                            Label("全盘分析完毕", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .padding(.top, 40)
                    
                    Divider()
                    
                    // 2. 胜率与目数差 (移植自你的旧代码逻辑)
                    if let analysis = game.moveAnalyses[game.currentTurn] {
                        let bWin = analysis.winrate * 100
                        let wWin = 100.0 - bWin
                        let lead = analysis.scoreLead
                        let leadStr = lead > 0 ? String(format: "黑领先 %.1f 目", lead) : String(format: "白领先 %.1f 目", abs(lead))
                        
                        VStack(spacing: 20) {
                            Text("当前局面评估")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("黑棋").bold()
                                    Spacer()
                                    Text(String(format: "%.1f%%", bWin)).font(.system(.body, design: .monospaced))
                                }
                                ProgressView(value: bWin, total: 100)
                                    .tint(.black)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                
                                HStack {
                                    Text("白棋").bold()
                                    Spacer()
                                    Text(String(format: "%.1f%%", wWin)).font(.system(.body, design: .monospaced))
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            
                            Text(leadStr)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(lead > 0 ? Color.black.opacity(0.1) : Color.white, in: Capsule())
                                .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.horizontal)
                    } else {
                        VStack {
                            Spacer()
                            ProgressView()
                            Text("分析数据加载中...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    // 3. 地盘开关 (适配 iPad UI)
                    Toggle("显示地盘归属", isOn: $game.showRealTimeTerritory)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                }
                .frame(width: 340)
                .background(.ultraThinMaterial)
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
