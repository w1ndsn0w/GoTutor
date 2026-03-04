import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root ContentView (管理全局状态)
struct MainScreen: View {
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

    @StateObject private var game: GoGame
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
        _game = StateObject(wrappedValue: GoGame(size: size))
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
                ReviewScreen(fileURL: url)
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
                    Toggle("导师", isOn: $game.isTutorMode)
                }
                .toggleStyle(CleanWhiteToggleStyle())
                
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

// MARK: - 右侧信息面板内容
struct SidePanelContent: View {
    @ObservedObject var game: GoGame
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("提子信息 (Prisoners)").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Divider()
                HStack {
                    PrisonerPill(isBlack: true, count: game.capturesBlack)
                    Spacer()
                    PrisonerPill(isBlack: false, count: game.capturesWhite)
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            
            Divider()

            if game.isTutorMode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DeepSeek 导师点评")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    Divider()
                    
                    if let msg = game.blunderMessage {
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        if game.isTutorThinking || !game.tutorExplanation.isEmpty {
                            Divider()
                            Text(game.tutorExplanation + (game.isTutorThinking ? " ✍🏻..." : ""))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .animation(.linear(duration: 0.1), value: game.tutorExplanation)
                        }

                        if game.previousBestMove != nil {
                            Text("💡 正确下法已在棋盘用蓝圈标出")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue.opacity(0.8))
                                .padding(.top, 4)
                        }
                    } else {
                        Text(game.isAnalyzingTutor ? "⏳ 等待 AI 算稳..." : (game.currentTurn == 0 ? "请落子，导师正在观战..." : "✅ 稳健的好棋！"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .animation(.easeInOut(duration: 0.2), value: game.blunderMessage)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if (game.showRealTimeTerritory || game.isEndGameScoring), let analysis = game.currentAnalysis {
                ScoreOverlayCard(territory: analysis, capturesBlack: game.capturesBlack, capturesWhite: game.capturesWhite)
                    .background(Color.clear)
                    .shadow(radius: 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
            
            // iPad 上按钮拉大，方便触摸
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: { game.undo() }) { Label("悔棋", systemImage: "arrow.uturn.backward") }
                        .disabled(game.moves.isEmpty)
                    
                    Button(action: { game.pass() }) { Label("Pass", systemImage: "hand.raised") }
                        .disabled(game.isGameOver)
                }
                
                Button(action: { game.reset() }) { Label("重新开始", systemImage: "arrow.counterclockwise") }
            }
            .buttonStyle(CleanWhiteButtonStyle())
            
            if let reason = game.lastIllegalReason {
                Label(reason.rawValue, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.red)
            } else if game.isEndGameScoring {
                Label("点击棋子修正死活", systemImage: "hand.tap").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// 以下是复用的 UI 组件，已替换 NSColor
struct PrisonerPill: View {
    let isBlack: Bool; let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isBlack ? Color.black : Color.white).overlay(Circle().stroke(Color.secondary, lineWidth: 1)).frame(width: 10, height: 10)
            Text("\(count) 子").font(.system(size: 14, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(isBlack ? Color.black.opacity(0.1) : Color.white, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }
}

struct ScoreOverlayCard: View {
    let territory: TerritoryAnalysis; let capturesBlack: Int; let capturesWhite: Int
    var body: some View {
        let blackScore = territory.blackTerritory.count + capturesBlack + territory.deadWhiteStones
        let whiteScore = territory.whiteTerritory.count + capturesWhite + territory.deadBlackStones
        VStack(alignment: .leading, spacing: 8) {
            Text("当前估算 (数目法)").font(.system(size: 13, weight: .semibold))
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("黑方总计"); Spacer(); Text("\(blackScore) 目").bold() }
                HStack { Text("白方总计"); Spacer(); Text("\(whiteScore) 目").bold() }
            }.font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("盘面黑地"); Spacer(); Text("\(territory.blackTerritory.count)") }
                HStack { Text("盘面白地"); Spacer(); Text("\(territory.whiteTerritory.count)") }
                HStack { Text("黑提白子"); Spacer(); Text("\(capturesBlack) (+\(territory.deadWhiteStones) 死子)") }
                HStack { Text("白提黑子"); Spacer(); Text("\(capturesWhite) (+\(territory.deadBlackStones) 死子)") }
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(14).frame(width: 260).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

struct CleanWhiteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12) // 按钮调厚一点
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
            .padding(.horizontal, 14).padding(.vertical, 8)
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
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground).opacity(configuration.isOn ? 1.0 : 0.6))
                .foregroundColor(configuration.isOn ? .accentColor : .primary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(configuration.isOn ? 0.06 : 0.0), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(configuration.isOn ? 1.0 : 0.97)
    }
}
// MARK: - SwiftUI 文件导出支持
struct GoGameDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var savedGame: SavedGame

    init(savedGame: SavedGame) {
        self.savedGame = savedGame
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.savedGame = try JSONDecoder().decode(SavedGame.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(savedGame)
        return .init(regularFileWithContents: data)
    }
}
