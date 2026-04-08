import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root ContentView (管理全局状态)
struct MainView: View {
    @State private var boardSizeOption: Int = 19
    @State private var pendingBoardSize: Int? = nil
    @State private var showSizeChangeAlert: Bool = false
    @State private var isBoardEmpty: Bool = true
    @State private var showSettings = false

    @AppStorage("showCoordinates") private var showCoordinates: Bool = true
    @AppStorage("showStarPoints") private var showStarPoints: Bool = true
    @AppStorage("showHoverGhost") private var showHoverGhost: Bool = true
    @AppStorage("showLastMoveMark") private var showLastMoveMark: Bool = true
    @AppStorage("useWoodBackground") private var useWoodBackground: Bool = true

    // iPad 横屏，高度通常在 700-800 左右，自动缩放
    private var boardPixelSize: CGFloat {
        switch boardSizeOption {
        case 9: return 720; case 13: return 700; default: return 680
        }
    }

    var body: some View {
        GameScreen(
            size: boardSizeOption, boardPixelSize: boardPixelSize,
            showCoordinates: showCoordinates, showStarPoints: showStarPoints,
            showHoverGhost: showHoverGhost, showLastMoveMark: showLastMoveMark,
            useWoodBackground: useWoodBackground,
            onOpenSettings: { showSettings = true },
            onUpdateBoardEmptyState: { empty in isBoardEmpty = empty },
            onRequestChangeSize: { newSize in
                guard newSize != boardSizeOption else { return }
                if isBoardEmpty { boardSizeOption = newSize; return }
                pendingBoardSize = newSize; showSizeChangeAlert = true
            }
        )
        .id(boardSizeOption)
        .alert("切换路数会重开棋局", isPresented: $showSizeChangeAlert) {
            Button("取消", role: .cancel) { pendingBoardSize = nil }
            Button("切换并重开", role: .destructive) { if let s = pendingBoardSize { boardSizeOption = s }; pendingBoardSize = nil }
        } message: { Text("当前棋局将被清空，是否继续？") }
        .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
    }
}

// MARK: - GameScreen (主控页面)
struct GameScreen: View {
    let size: Int; let boardPixelSize: CGFloat
    let showCoordinates: Bool; let showStarPoints: Bool; let showHoverGhost: Bool; let showLastMoveMark: Bool; let useWoodBackground: Bool
    let onOpenSettings: () -> Void; let onUpdateBoardEmptyState: (Bool) -> Void; let onRequestChangeSize: (Int) -> Void

    @StateObject private var game: GoGameViewModel
    @State private var hoverPoint: Point? = nil
    @State private var showGameOverAlert = false
    @State private var reviewFileURL: URL? = nil
    // 【适配 iPad】处理文件导入导出和复盘弹窗
    @State private var showFileImporter = false
    @State private var showReviewSheet = false
    @State private var showFileExporter = false
    @State private var documentToSave: GoGameDocument?

    
    init(size: Int, boardPixelSize: CGFloat, showCoordinates: Bool, showStarPoints: Bool, showHoverGhost: Bool, showLastMoveMark: Bool, useWoodBackground: Bool, onOpenSettings: @escaping () -> Void, onUpdateBoardEmptyState: @escaping (Bool) -> Void, onRequestChangeSize: @escaping (Int) -> Void) {
        self.size = size; self.boardPixelSize = boardPixelSize
        self.showCoordinates = showCoordinates; self.showStarPoints = showStarPoints; self.showHoverGhost = showHoverGhost; self.showLastMoveMark = showLastMoveMark; self.useWoodBackground = useWoodBackground
        self.onOpenSettings = onOpenSettings; self.onUpdateBoardEmptyState = onUpdateBoardEmptyState; self.onRequestChangeSize = onRequestChangeSize
        _game = StateObject(wrappedValue: GoGameViewModel(size: size))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.regularMaterial)

            Divider()

            HStack(spacing: 0) {
                // --- 左侧：棋盘区域 ---
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    GoBoardWithCoordinatesView(game: game, hoverPoint: $hoverPoint, showCoordinates: showCoordinates, showStarPoints: showStarPoints, showHoverGhost: showHoverGhost, showLastMoveMark: showLastMoveMark, useWoodBackground: useWoodBackground, territory: game.currentAnalysis)
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // 让它填满左边
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()

                // --- 右侧：信息面板 ---
                // iPad 上适合把侧边栏加宽到 280-300，方便手指点按
                SidePanelContent(game: game)
                    .frame(width: 300)
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            game.startEngine() // 视图加载时自动唤醒引擎
            onUpdateBoardEmptyState(game.moves.isEmpty)
        }
        .onChange(of: game.moves.count) { _, _ in onUpdateBoardEmptyState(game.moves.isEmpty) }
        .onChange(of: game.isGameOver) { _, newValue in if newValue { showGameOverAlert = true } }
        .alert("对局结束", isPresented: $showGameOverAlert) {
            Button("确定") { }; Button("重新开始") { game.reset() }
        } message: { Text("连续两次 Pass。") }
        // 【适配 iPad】本地文件选择器

        // 1. 读取文件的逻辑
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                // 获取到文件路径后，通过环境变量触发全屏复盘页
                let _ = url.startAccessingSecurityScopedResource()
                self.reviewFileURL = url
                self.showReviewSheet = true
            case .failure(let error):
                print("读取失败: \(error)")
            }
        }
        // 系统原生保存面板
         .fileExporter(
             isPresented: $showFileExporter,
             document: documentToSave,
             contentType: .json,
             defaultFilename: "GoTutor_棋谱_\(Int(Date().timeIntervalSince1970))"
         ) { result in
             switch result {
             case .success(let url):
                 print("✅ 棋谱已成功保存至: \(url)")
             case .failure(let error):
                 print("❌ 保存失败: \(error)")
             }
         }
        // 2. 挂载复盘页 (全屏覆盖)
        .fullScreenCover(isPresented: $showReviewSheet) {
            if let url = reviewFileURL {
                ReviewView(fileURL: url)
                    .onDisappear {
                        url.stopAccessingSecurityScopedResource()
                    }
            }
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 16) {
            Text("围棋").font(.system(size: 22, weight: .semibold))
            
            Picker("", selection: Binding(get: { size }, set: { onRequestChangeSize($0) })) {
                Text("9路").tag(9); Text("13路").tag(13); Text("19路").tag(19)
            }.pickerStyle(.segmented).frame(width: 150)
            
            statusPill
            
            Spacer()
            
            HStack(spacing: 12) {
                Group {
                    Button(action: { showFileImporter = true }) { Label("读谱", systemImage: "folder") }
                    Button(action: {
                        // 1. 生成数据装进快递盒
                        documentToSave = GoGameDocument(savedGame: game.generateSaveData())
                        // 2. 唤醒系统的保存面板
                        showFileExporter = true
                    }) { Label("保存", systemImage: "square.and.arrow.down") }
                }
                .buttonStyle(HeaderButtonStyle())

                Divider().frame(height: 16)

                Group {
                    Toggle("AI陪练", isOn: $game.isAIBattleMode)
                    
                    // 当开启 AI 陪练时，显示执黑执白选项
                    if game.isAIBattleMode {
                        Picker("", selection: $game.aiPlayerColor) {
                            Text("AI 执白").tag(Stone.white)
                            Text("AI 执黑").tag(Stone.black)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                        // 增加一点过渡动画，让 UI 展开时更平滑
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Toggle("导师", isOn: $game.isTutorMode)
                }
                .toggleStyle(CleanWhiteToggleStyle())
                .animation(.easeInOut(duration: 0.2), value: game.isAIBattleMode) // 绑定动画
                
                Divider().frame(height: 16)

                Group {
                    Toggle("形势", isOn: $game.showRealTimeTerritory)
                    Toggle("结算", isOn: $game.isEndGameScoring)
                }
                .toggleStyle(CleanWhiteToggleStyle())

                Divider().frame(height: 16)

                Button(action: { onOpenSettings() }) { Image(systemName: "gearshape") }
                .buttonStyle(HeaderButtonStyle())
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(game.currentPlayer == .black ? Color.black : Color.white).overlay(Circle().stroke(Color.secondary, lineWidth: 1)).frame(width: 12, height: 12)
            Text(game.isGameOver ? "对局结束" : (game.currentPlayer == .black ? "黑方落子" : "白方落子"))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}
