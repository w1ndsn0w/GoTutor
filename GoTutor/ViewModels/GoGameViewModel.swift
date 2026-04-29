import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers

enum AIBattleDifficulty: String, CaseIterable, Identifiable, Sendable {
    case beginner20k
    case kyu10
    case amateur1d
    case amateur3d
    case amateur5d
    case pro1p
    case pro5p
    case pro9p

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner20k: return "启蒙 20级"
        case .kyu10: return "级位 10级"
        case .amateur1d: return "业余初段"
        case .amateur3d: return "业余3段"
        case .amateur5d: return "业余5段"
        case .pro1p: return "职业初段"
        case .pro5p: return "职业5段"
        case .pro9p: return "职业9段"
        }
    }

    func maxVisits(boardSize: Int, moveCount: Int) -> Int {
        let base: Int
        switch self {
        case .beginner20k: base = 8
        case .kyu10: base = 18
        case .amateur1d: base = 45
        case .amateur3d: base = 90
        case .amateur5d: base = 150
        case .pro1p: base = 260
        case .pro5p: base = 420
        case .pro9p: base = 700
        }

        let boardScale: Double
        switch boardSize {
        case 9: boardScale = 0.55
        case 13: boardScale = 0.75
        default: boardScale = 1.0
        }

        let openingScale = moveCount < max(10, boardSize) ? 1.25 : 1.0
        return max(4, Int(Double(base) * boardScale * openingScale))
    }
}

@MainActor
final class GoGameViewModel: ObservableObject {
    @Published private(set) var size: Int
    // 🌍 全局唯一的身份证，防止多开窗口时数据串台
    let gameId = UUID().uuidString
    
    @Published private(set) var board: [[Stone]]
    @Published private(set) var currentPlayer: Stone = .black
    @Published private(set) var capturesBlack: Int = 0
    @Published private(set) var capturesWhite: Int = 0
    @Published private(set) var consecutivePasses: Int = 0
    @Published private(set) var isGameOver: Bool = false
    
    @Published private(set) var moves: [Move] = []
    @Published private(set) var lastMove: Move? = nil
    @Published private(set) var lastIllegalReason: IllegalReason? = nil
    
    @Published var isAIBattleMode: Bool = false {
        didSet {
            cancelPendingAIMove()
            cancelScheduledAnalysis(clearInFlightState: true)
            if isAIBattleMode { scheduleAnalysis() }
        }
    }
    @Published var aiPlayerColor: Stone = .white {
        didSet {
            if isAIBattleMode {
                cancelPendingAIMove()
                cancelScheduledAnalysis(clearInFlightState: true)
                scheduleAnalysis()
            }
        }
    }
    @Published var aiDifficulty: AIBattleDifficulty = .amateur1d {
        didSet {
            if isAIBattleMode {
                cancelPendingAIMove()
                cancelScheduledAnalysis(clearInFlightState: true)
                scheduleAnalysis()
            }
        }
    }
    @Published var isAICoachHintEnabled: Bool = false {
        didSet {
            guard isAIBattleMode else { return }
            cancelScheduledAnalysis(clearInFlightState: true)
            scheduleAnalysis()
        }
    }
    // MARK: - 导师模式核心状态
    @Published var isTutorMode: Bool = false {
        didSet {
            if isTutorMode {
                checkedTurnForTutor = -1
                isAnalyzingTutor = true
                if isAIBattleMode { scheduleAnalysis() }
                executeBlunderCheck(forTurn: currentTurn)
            } else {
                tutorCheckTimer?.cancel()
            }
        }
    }
    @Published var previousBestMove: Point? = nil
    @Published var blunderMessage: String? = nil
    @Published var tutorExplanation: String = ""
    @Published var isTutorThinking: Bool = false
    @Published var isAnalyzingTutor: Bool = false
    
    private var checkedTurnForTutor: Int = -1
    private var tutorCheckTimer: DispatchWorkItem?
    
    @Published var reviewBestMoveHint: Point? = nil
    
    @Published var showRealTimeTerritory: Bool = false {
        didSet {
            if showRealTimeTerritory { isEndGameScoring = false }
            if let ownership = moveAnalyses[currentTurn]?.ownership { latestOwnership = ownership }
            updateTerritory()
        }
    }
    @Published var isEndGameScoring: Bool = false {
        didSet {
            if isEndGameScoring {
                showRealTimeTerritory = false
                if let ownership = moveAnalyses[currentTurn]?.ownership { latestOwnership = ownership }
                if let own = latestOwnership { seedDeadStones(ownership: own) }
            }
            else { deadStones.removeAll() }
            updateTerritory()
        }
    }
    
    @Published private(set) var currentAnalysis: TerritoryAnalysis? = nil
    @Published private(set) var deadStones: Set<Point> = []
    @Published private(set) var moveAnalyses: [Int: MoveAnalysis] = [:]
    
    @Published var currentTurn: Int = 0
    @Published var isReviewMode: Bool = false
    @Published var analysisProgress: Double = 1.0
    @Published private(set) var isEngineReady: Bool = false
    @Published private(set) var engineStatusMessage: String? = nil
    @Published private(set) var isAIThinking: Bool = false
    @Published private(set) var isHintThinking: Bool = false
    
    private var snapshots: [GameSnapshot] = []
    private var positionHistory: Set<String> = []
    private var currentFileURL: URL? = nil
    private var currentRecordDate: Date? = nil
    private var currentRecordTitle: String? = nil
    private var currentBlackPlayerName: String? = nil
    private var currentWhitePlayerName: String? = nil
    
    // 【核心】接入单例引擎
    private let aiEngine = KataGoWrapper.shared()
    private var latestOwnership: [Double]? = nil
    private var analysisTimer: DispatchWorkItem?
    private var expectedBatchResponses = 0
    private var receivedBatchResponses = 0
    private var completedBatchResponsesAtStart = 0
    private var notificationTask: Task<Void, Never>?
    private var aiMoveTask: Task<Void, Never>?
    private var pendingAIAnalysisTurn: Int? = nil
    private var pendingHintAnalysisTurn: Int? = nil

    var isAITurn: Bool {
        isAIBattleMode && currentPlayer == aiPlayerColor && !isGameOver && !isReviewMode
    }

    var shouldShowAICoachHints: Bool {
        isAIBattleMode && isAICoachHintEnabled && !isAITurn && !isReviewMode
    }

    private var aiBattleMaxVisits: Int {
        aiDifficulty.maxVisits(boardSize: size, moveCount: moves.count)
    }

    init(size: Int = 19) {
        self.size = size
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
        self.positionHistory.insert(Self.hashBoard(self.board))
        notificationTask = Task {
            for await notification in NotificationCenter.default.notifications(named: NSNotification.Name("KataGoJSONBroadcast")) {
                if let jsonString = notification.userInfo?["json"] as? String {
                    self.handleKataGoJSON(jsonString)
                }
            }
        }
    }
    
    deinit {
        notificationTask?.cancel()
    }
    
    // MARK: - 引擎管理
    func startEngine() {
        guard !isEngineReady else { return }
        guard let modelPath = Bundle.main.path(forResource: "model", ofType: "bin.gz"),
              let configPath = Bundle.main.path(forResource: "analysis", ofType: "cfg") else {
            engineStatusMessage = "找不到模型文件或 analysis.cfg 配置"
            return
        }
        engineStatusMessage = aiEngine.setEngineWithModel(modelPath, config: configPath)
        isEngineReady = true
    }

    private func ensureEngineStarted() -> Bool {
        startEngine()
        return isEngineReady
    }
    
    // 🚨 修正：将 handleKataGoJSON 独立出来，不再嵌套在别的方法内部
    private func handleKataGoJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let response = try JSONDecoder().decode(KataGoResponse.self, from: data)
            
            // 核心防御网：必须带着我的专属 UUID，否则丢弃数据
            guard let responseId = response.id, responseId.hasPrefix(self.gameId) else { return }
            
            let turn = response.turnNumber ?? 0

            let shouldScheduleAIMove = self.isAIBattleMode
                && turn == self.currentTurn
                && self.currentPlayer == self.aiPlayerColor
                && response.moveInfos?.first?.move != nil

            if responseId.contains("_query_"), self.pendingAIAnalysisTurn == turn {
                self.pendingAIAnalysisTurn = nil
                if !shouldScheduleAIMove {
                    self.isAIThinking = false
                }
            }
            if responseId.contains("_human_hint_"), self.pendingHintAnalysisTurn == turn {
                self.pendingHintAnalysisTurn = nil
                self.isHintThinking = false
            }
            
            if let info = response.rootInfo, let wr = info.winrate, let sl = info.scoreLead {
                var bestMovePt: Point? = nil
                var candidates: [CandidateMove] = []
                
                if let moveInfos = response.moveInfos {
                    // 1. 提取第一名作为 bestMove
                    if let bestMoveStr = moveInfos.first?.move {
                        bestMovePt = Point(gtp: bestMoveStr, boardSize: self.size)
                    }
                    
                    // 2. 提取前 3 名，组装成你极其强大的 CandidateMove
                    for (index, moveInfo) in moveInfos.prefix(3).enumerated() {
                        if let mWr = moveInfo.winrate, let mSl = moveInfo.scoreLead {
                            candidates.append(CandidateMove(
                                move: moveInfo.move, // 直接存字母坐标，如 "D4"
                                winrate: mWr,
                                scoreLead: mSl,
                                pv: moveInfo.pv ?? [], // 顺手把未来变化图也存了！
                                order: index + 1
                            ))
                        }
                    }
                }
                
                self.moveAnalyses[turn] = MoveAnalysis(winrate: wr, scoreLead: sl, ownership: response.ownership, bestMove: bestMovePt, candidateMoves: candidates)
            }

            if responseId.hasSuffix("batch_review") {
                self.receivedBatchResponses += 1
                let total = max(1, self.completedBatchResponsesAtStart + self.expectedBatchResponses)
                let completed = self.completedBatchResponsesAtStart + self.receivedBatchResponses
                let progress = min(1.0, Double(completed) / Double(total))
                self.analysisProgress = progress
                if progress >= 1.0 { self.autoSaveToCurrentFile() }
            }
            
            
            if turn == self.currentTurn, let ownership = response.ownership, ownership.count == self.size * self.size {
                self.latestOwnership = ownership
                self.updateTerritory()
                
                if self.isTutorMode && self.checkedTurnForTutor != turn && turn > 0 {
                    let lastPlayer = self.moves[turn - 1].player
                    let isHumanMove = !(self.isAIBattleMode && lastPlayer == self.aiPlayerColor)
                    if isHumanMove {
                        self.tutorCheckTimer?.cancel()
                        let workItem = DispatchWorkItem { [weak self] in self?.executeBlunderCheck(forTurn: turn) }
                        self.tutorCheckTimer = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                    }
                }
            }
            
            if shouldScheduleAIMove,
               let bestMove = response.moveInfos?.first?.move {
                self.scheduleAIMove(bestMove, forTurn: turn)
            }
        } catch { }
    }
    
    // MARK: - 导师引擎
    private func resetTutorUIForNewMove(isHuman: Bool) {
        if isHuman {
            blunderMessage = nil
            tutorExplanation = ""
            isTutorThinking = false
            isAnalyzingTutor = true
            checkedTurnForTutor = -1
        }
    }
    
    private func executeBlunderCheck(forTurn targetTurn: Int) {
            guard isTutorMode, targetTurn > 0 else {
                isAnalyzingTutor = false
                return
            }
            guard checkedTurnForTutor != targetTurn else {
                isAnalyzingTutor = false // 增加防御：已检查过则关闭转圈
                return
            }
            
            let isLatestHumanMove = (targetTurn == currentTurn) || (isAIBattleMode && targetTurn == currentTurn - 1)
            guard isLatestHumanMove else {
                isAnalyzingTutor = false // 增加防御：非最新手则关闭转圈
                return
            }
            
            guard let current = moveAnalyses[targetTurn], let previous = moveAnalyses[targetTurn - 1] else {
                // 🚨 核心修复：如果是复盘模式且缺失数据，直接解除转圈锁定
                if isReviewMode { isAnalyzingTutor = false }
                return
            }
            
            checkedTurnForTutor = targetTurn
            isAnalyzingTutor = false // 正常流程中，拿到数据后立即关闭转圈
            
            let actualMove = moves[targetTurn - 1]
            var actualPt: Point? = nil
            if case .place(let p) = actualMove.kind { actualPt = p }
            
            let lastPlayer = actualMove.player
            
            if !isReviewMode && lastPlayer == aiPlayerColor {
                return
            }
            
            let wrDrop = lastPlayer == .black ? (previous.winrate - current.winrate) : (current.winrate - previous.winrate)
            let slDrop = lastPlayer == .black ? (previous.scoreLead - current.scoreLead) : (current.scoreLead - previous.scoreLead)
            
            let shouldComment = wrDrop > 0.02 && (actualPt != previous.bestMove || slDrop > 2.0)

            if let actual = actualPt, let best = previous.bestMove, shouldComment {
                let wrPercent = String(format: "%.1f%%", wrDrop * 100)
                let slPoints = String(format: "%.1f", slDrop)
                let rating: String
                if wrDrop > 0.20 {
                    rating = "重大失误"
                } else if wrDrop > 0.08 {
                    rating = "明显失误"
                } else {
                    rating = "可改进的一手"
                }
                
                blunderMessage = "\(rating)\n胜率损失 \(wrPercent) (目差约 \(slPoints) 目)"
                previousBestMove = best
                tutorExplanation = ""
                isTutorThinking = true
                
                let colorStr = lastPlayer == .black ? "黑棋" : "白棋"
                let actualStr = actual.toGTP(boardSize: size)
                let bestStr = best.toGTP(boardSize: size)
                let prompt = "当前第 \(targetTurn) 手，人类执\(colorStr)下在 \(actualStr)，导致胜率暴跌 \(wrPercent)（亏损 \(slPoints) 目）。KataGo 推荐的最佳选点是 \(bestStr)。请点评。"
                
                Task {
                    do {
                        let stream = AITutorNetworkManager.shared.fetchExplanationStream(prompt: prompt)
                        for try await chunk in stream {
                            self.tutorExplanation += chunk
                        }
                        self.isTutorThinking = false
                    } catch {
                        DispatchQueue.main.async {
                            self.tutorExplanation = "网络请求失败，请检查 API Key..."
                            self.isTutorThinking = false
                        }
                    }
                }
            } else {
                blunderMessage = nil
                previousBestMove = nil
                tutorExplanation = ""
                isTutorThinking = false
            }
        }
    private func updateReviewHint() {
        guard isReviewMode, currentTurn > 0 else { reviewBestMoveHint = nil; return }
        guard let currentAnalysis = moveAnalyses[currentTurn], let prevAnalysis = moveAnalyses[currentTurn - 1], let aiBest = prevAnalysis.bestMove else { reviewBestMoveHint = nil; return }
        let actualMove = moves[currentTurn - 1]
        var actualPt: Point? = nil; if case .place(let p) = actualMove.kind { actualPt = p }
        let lastPlayer = actualMove.player
        let wrDrop = lastPlayer == .black ? (prevAnalysis.winrate - currentAnalysis.winrate) : (currentAnalysis.winrate - prevAnalysis.winrate)
        if actualPt != aiBest && wrDrop > 0.02 { reviewBestMoveHint = aiBest } else { reviewBestMoveHint = nil }
    }
    
    // MARK: - Core Play API
    @discardableResult
    func place(atRow r: Int, col c: Int) -> Bool {
        if isReviewMode { return false }
        lastIllegalReason = nil; guard !isGameOver else { return false }
        let p = Point(r: r, c: c); guard inBounds(p) else { lastIllegalReason = .outOfBounds; return false }
        guard board[r][c] == .empty else { lastIllegalReason = .occupied; return false }
        cancelPendingAIMove()
        
        pushSnapshot()
        var newBoard = board; newBoard[r][c] = currentPlayer; var capturedPoints: [Point] = []
        for nb in neighbors(of: p) { if newBoard[nb.r][nb.c] == currentPlayer.opponent { let group = collectGroup(board: newBoard, start: nb); if liberties(of: group, board: newBoard) == 0 { capturedPoints.append(contentsOf: group) } } }
        for cp in capturedPoints { newBoard[cp.r][cp.c] = .empty }
        let myGroup = collectGroup(board: newBoard, start: p); if liberties(of: myGroup, board: newBoard) == 0 { restoreFromSnapshotPop(); lastIllegalReason = .suicide; return false }
        let newHash = Self.hashBoard(newBoard); if positionHistory.contains(newHash) { restoreFromSnapshotPop(); lastIllegalReason = .ko; return false }
        
        board = newBoard; positionHistory.insert(newHash)
        if currentPlayer == .black { capturesBlack += capturedPoints.count } else { capturesWhite += capturedPoints.count }
        
        let mv = Move(player: currentPlayer, kind: .place(p), captured: capturedPoints)
        moves.append(mv); lastMove = mv; consecutivePasses = 0;
        
        let isHumanMove = !(isAIBattleMode && currentPlayer == aiPlayerColor)
        currentPlayer = currentPlayer.next; currentTurn = moves.count
        
        resetTutorUIForNewMove(isHuman: isHumanMove)
        scheduleAnalysis()
        return true
    }
    
    func pass() {
        if isReviewMode { return }
        lastIllegalReason = nil; guard !isGameOver else { return }
        cancelPendingAIMove()
        pushSnapshot(); let mv = Move(player: currentPlayer, kind: .pass, captured: [])
        moves.append(mv); lastMove = mv; consecutivePasses += 1
        if consecutivePasses >= 2 { isGameOver = true }
        
        let isHumanMove = !(isAIBattleMode && currentPlayer == aiPlayerColor)
        currentPlayer = currentPlayer.next; currentTurn = moves.count
        
        resetTutorUIForNewMove(isHuman: isHumanMove)
        scheduleAnalysis()
    }
    
    func undo() {
        if isReviewMode { return }; guard let snap = snapshots.popLast() else { return }
        cancelPendingAIMove()
        restore(from: snap); currentTurn = moves.count
        resetTutorUIForNewMove(isHuman: true)
        scheduleAnalysis()
    }
    
    func reset() {
        cancelPendingAIMove()
        cancelScheduledAnalysis(clearInFlightState: true)
        board = Array(repeating: Array(repeating: .empty, count: size), count: size)
        currentPlayer = .black; capturesBlack = 0; capturesWhite = 0; consecutivePasses = 0; isGameOver = false; moves = []; lastMove = nil; lastIllegalReason = nil
        snapshots = []; positionHistory = [Self.hashBoard(board)]
        showRealTimeTerritory = false; isEndGameScoring = false; latestOwnership = nil; moveAnalyses = [:]
        currentTurn = 0; isReviewMode = false; analysisProgress = 1.0
        currentFileURL = nil; currentRecordDate = nil; currentRecordTitle = nil; currentBlackPlayerName = nil; currentWhitePlayerName = nil
        
        resetTutorUIForNewMove(isHuman: true)
        isAnalyzingTutor = false
        scheduleAnalysis()
    }
    
    func toggleDeadStone(atRow r: Int, col c: Int) {
        guard isEndGameScoring else { return }
        let p = Point(r: r, c: c); guard inBounds(p), board[r][c] != .empty else { return }
        let group = collectGroup(board: board, start: p)
        if deadStones.contains(p) { deadStones.subtract(group) } else { deadStones.formUnion(group) }
        updateTerritory()
    }
    
    func loadGame(from url: URL) {
        cancelPendingAIMove()
        do {
            let data = try Data(contentsOf: url)
            let savedGame = try SavedGame.parse(from: data, preferredFileExtension: url.pathExtension)
            self.currentFileURL = url.pathExtension.lowercased() == "json" ? url : nil
            load(savedGame)
            
            if self.moves.isEmpty {
                self.analysisProgress = 1.0
            } else if savedGame.hasCompleteAIAnalysis {
                self.analysisProgress = 1.0
            } else {
                let missingTurns = savedGame.missingAnalysisTurns()
                self.analysisProgress = Double(savedGame.analyzedTurnCount) / Double(max(1, savedGame.totalAnalysisTurnCount))
                requestBatchAnalysis(analyzeTurns: missingTurns, completedAtStart: savedGame.analyzedTurnCount)
            }
            setTurn(0)
        } catch { print("❌ 读取失败: \(error)") }
    }

    private func load(_ savedGame: SavedGame) {
        cancelScheduledAnalysis(clearInFlightState: true)
        size = savedGame.size
        board = Array(repeating: Array(repeating: .empty, count: savedGame.size), count: savedGame.size)
        currentPlayer = .black
        capturesBlack = 0
        capturesWhite = 0
        consecutivePasses = 0
        isGameOver = false
        lastMove = nil
        lastIllegalReason = nil
        snapshots = []
        positionHistory = [Self.hashBoard(board)]
        latestOwnership = nil
        currentAnalysis = nil
        deadStones = []
        moves = savedGame.moves
        moveAnalyses = savedGame.analyses
        currentRecordDate = savedGame.date
        currentRecordTitle = savedGame.title
        currentBlackPlayerName = savedGame.blackPlayerName
        currentWhitePlayerName = savedGame.whitePlayerName
        isReviewMode = true
        currentTurn = 0
    }
    
    func setTurn(_ turn: Int) {
        cancelPendingAIMove()
        let safeTurn = max(0, min(turn, moves.count)); currentTurn = safeTurn; rebuildBoard(upTo: safeTurn)
        if let analysis = moveAnalyses[safeTurn], let own = analysis.ownership { self.latestOwnership = own; self.updateTerritory() } else { self.latestOwnership = nil; currentAnalysis = nil }
        
        resetTutorUIForNewMove(isHuman: true)
        executeBlunderCheck(forTurn: currentTurn)
        updateReviewHint()
    }
    
    private func rebuildBoard(upTo targetTurn: Int) {
        board = Array(repeating: Array(repeating: .empty, count: size), count: size); currentPlayer = .black; capturesBlack = 0; capturesWhite = 0; lastMove = nil; lastIllegalReason = nil
        for i in 0..<targetTurn {
            let move = moves[i], color = move.player
            if case .place(let p) = move.kind {
                guard inBounds(p) else { continue }
                board[p.r][p.c] = color; var capturedPoints: [Point] = []
                for nb in neighbors(of: p) { if board[nb.r][nb.c] == color.opponent { let group = collectGroup(board: board, start: nb); if liberties(of: group, board: board) == 0 { capturedPoints.append(contentsOf: group) } } }
                for cp in capturedPoints { board[cp.r][cp.c] = .empty }; if color == .black { capturesBlack += capturedPoints.count } else { capturesWhite += capturedPoints.count }
            }
            currentPlayer = color.next; lastMove = move
        }
    }
    
    func generateSaveData(title: String? = nil, blackPlayerName: String? = nil, whitePlayerName: String? = nil) -> SavedGame {
        return SavedGame(
            size: size,
            date: Date(),
            title: title,
            blackPlayerName: blackPlayerName,
            whitePlayerName: whitePlayerName,
            moves: moves,
            analyses: moveAnalyses
        )
    }

    func teachingFeedback(for turn: Int) -> TeachingFeedback? {
        TeachingFeedbackAnalyzer.feedback(for: turn, moves: moves, analyses: moveAnalyses, boardSize: size)
    }

    func keyTeachingFeedbacks(limit: Int = 6) -> [TeachingFeedback] {
        TeachingFeedbackAnalyzer.keyFeedbacks(moves: moves, analyses: moveAnalyses, boardSize: size, limit: limit)
    }
    
    private func pushSnapshot() {
        snapshots.append(GameSnapshot(board: board, currentPlayer: currentPlayer, capturesBlack: capturesBlack, capturesWhite: capturesWhite, consecutivePasses: consecutivePasses, isGameOver: isGameOver, lastMove: lastMove, lastIllegalReason: lastIllegalReason, positionHistory: positionHistory, moves: moves))
    }
    
    private func restoreFromSnapshotPop() {
        guard let snap = snapshots.popLast() else { return }
        restore(from: snap)
    }
    
    private func restore(from snap: GameSnapshot) {
        board = snap.board; currentPlayer = snap.currentPlayer; capturesBlack = snap.capturesBlack; capturesWhite = snap.capturesWhite; consecutivePasses = snap.consecutivePasses; isGameOver = snap.isGameOver; lastMove = snap.lastMove; lastIllegalReason = snap.lastIllegalReason; positionHistory = snap.positionHistory; moves = snap.moves
    }
    
    private var analysisTask: Task<Void, Never>?

    private func cancelScheduledAnalysis(clearInFlightState: Bool = false) {
        analysisTask?.cancel()
        analysisTask = nil
        if clearInFlightState {
            pendingAIAnalysisTurn = nil
            pendingHintAnalysisTurn = nil
            isAIThinking = false
            isHintThinking = false
        }
    }

    private func cancelPendingAIMove(clearThinking: Bool = true) {
        let hadPendingMove = aiMoveTask != nil
        aiMoveTask?.cancel()
        aiMoveTask = nil
        if clearThinking && hadPendingMove { isAIThinking = false }
    }

    private func scheduleAIMove(_ bestMove: String, forTurn turn: Int) {
        cancelPendingAIMove(clearThinking: false)
        isAIThinking = true
        aiMoveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            guard self.isAIBattleMode,
                  self.currentTurn == turn,
                  self.currentPlayer == self.aiPlayerColor,
                  !self.isGameOver else {
                self.isAIThinking = false
                return
            }

            if bestMove.lowercased() == "pass" {
                self.pass()
            } else if let point = Point(gtp: bestMove, boardSize: self.size) {
                self.place(atRow: point.r, col: point.c)
            } else {
                self.isAIThinking = false
            }
        }
    }

    private func scheduleAnalysis() {
        cancelScheduledAnalysis()
        pendingHintAnalysisTurn = nil
        isHintThinking = false
        if isAIBattleMode {
            if currentPlayer == aiPlayerColor {
                requestSingleAnalysis(maxVisits: aiBattleMaxVisits)
            } else if isAICoachHintEnabled || isTutorMode {
                analysisTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    let visits = self.isAICoachHintEnabled ? max(18, self.aiBattleMaxVisits / 4) : 24
                    self.requestSingleAnalysis(maxVisits: visits, includeOwnership: true, idSuffix: "human_hint")
                }
            }
            return
        }

        analysisTask = Task {
            // 等待 3 秒 (Swift 6 可以直接用 .seconds(3))
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self.requestSingleAnalysis() // 安全调用，继承了 @MainActor
        }
    }
    
    // MARK: - 网络请求
    private func requestSingleAnalysis(maxVisits: Int = 50, includeOwnership: Bool = true, idSuffix: String = "query") {
        guard ensureEngineStarted() else { return }

        var gtpMoves: [[String]] = []
        for move in moves {
            let playerStr = move.player == .black ? "B" : "W"
            switch move.kind {
            case .place(let p): gtpMoves.append([playerStr, p.toGTP(boardSize: size)])
            case .pass: gtpMoves.append([playerStr, "pass"])
            }
        }
        
        // 🚨 修正：此处保持 query 格式，并戴上身份证 gameId
        let queryDict: [String: Any] = [
            "id": "\(gameId)_\(idSuffix)_\(moves.count)",
            "moves": gtpMoves,
            "rules": "chinese",
            "boardXSize": size,
            "boardYSize": size,
            "analyzeTurns": [gtpMoves.count],
            "maxVisits": maxVisits,
            "includeOwnership": includeOwnership
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: queryDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if idSuffix == "query", isAIBattleMode, currentPlayer == aiPlayerColor {
                pendingAIAnalysisTurn = moves.count
                isAIThinking = true
            } else if idSuffix == "human_hint" {
                pendingHintAnalysisTurn = moves.count
                isHintThinking = true
            }
            aiEngine.sendQuery(jsonString)
        }
    }
    
    private func requestBatchAnalysis(analyzeTurns: [Int], completedAtStart: Int = 0) {
        guard !analyzeTurns.isEmpty else {
            analysisProgress = 1.0
            autoSaveToCurrentFile()
            return
        }
        guard ensureEngineStarted() else { return }

        var gtpMoves: [[String]] = []
        for move in moves {
            let playerStr = move.player == .black ? "B" : "W"
            switch move.kind {
            case .place(let p): gtpMoves.append([playerStr, p.toGTP(boardSize: size)])
            case .pass: gtpMoves.append([playerStr, "pass"])
            }
        }
        
        expectedBatchResponses = analyzeTurns.count
        receivedBatchResponses = 0
        completedBatchResponsesAtStart = completedAtStart
        let total = max(1, completedAtStart + analyzeTurns.count)
        analysisProgress = Double(completedAtStart) / Double(total)
        
        let queryDict: [String: Any] = [
            "id": "\(gameId)_batch_review",
            "moves": gtpMoves,
            "rules": "chinese",
            "boardXSize": size,
            "boardYSize": size,
            "analyzeTurns": analyzeTurns,
            "maxVisits": highRankReviewMaxVisits,
            "includeOwnership": true,
            "includePolicy": true
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: queryDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            aiEngine.sendQuery(jsonString)
        }
    }

    private var highRankReviewMaxVisits: Int {
        max(64, AIBattleDifficulty.amateur3d.maxVisits(boardSize: size, moveCount: moves.count))
    }
    
    // MARK: - 计目系统
    private func updateTerritory() {
        guard showRealTimeTerritory || isEndGameScoring else {
            currentAnalysis = nil; deadStones.removeAll(); return
        }
        if latestOwnership == nil, let ownership = moveAnalyses[currentTurn]?.ownership {
            latestOwnership = ownership
        }
        guard let ownership = latestOwnership, ownership.count == size * size else { return }
        
        if showRealTimeTerritory { seedDeadStones(ownership: ownership) }
        
        var blackTerritory: Set<Point> = []; var whiteTerritory: Set<Point> = []; var neutral: Set<Point> = []
        var deadBlackStones = 0; var deadWhiteStones = 0
        
        for r in 0..<size {
            for c in 0..<size {
                let p = Point(r: r, c: c); let stone = board[r][c]; let own = ownership[r * size + c]
                let isDead = deadStones.contains(p)
                
                if stone == .black && isDead {
                    deadBlackStones += 1; whiteTerritory.insert(p)
                } else if stone == .white && isDead {
                    deadWhiteStones += 1; blackTerritory.insert(p)
                } else if stone == .empty {
                    if own > 0.5 { blackTerritory.insert(p) }
                    else if own < -0.5 { whiteTerritory.insert(p) }
                    else { neutral.insert(p) }
                }
            }
        }
        
        currentAnalysis = TerritoryAnalysis(blackTerritory: blackTerritory, whiteTerritory: whiteTerritory, neutral: neutral, deadBlackStones: deadBlackStones, deadWhiteStones: deadWhiteStones)
    }
    
    private func seedDeadStones(ownership: [Double]) {
        var aiDeadStones: Set<Point> = []
        for r in 0..<size {
            for c in 0..<size {
                let stone = board[r][c]; let p = Point(r: r, c: c)
                if stone == .black && ownership[r * size + c] < -0.5 { aiDeadStones.insert(p) }
                if stone == .white && ownership[r * size + c] > 0.5 { aiDeadStones.insert(p) }
            }
        }
        self.deadStones = aiDeadStones
    }
    
    private func autoSaveToCurrentFile() {
        guard let url = currentFileURL else { return }
        let gameData = SavedGame(
            size: size,
            date: currentRecordDate ?? Date(),
            title: currentRecordTitle,
            blackPlayerName: currentBlackPlayerName,
            whitePlayerName: currentWhitePlayerName,
            moves: moves,
            analyses: moveAnalyses
        )
        try? JSONEncoder().encode(gameData).write(to: url)
    }
    
    private func inBounds(_ p: Point) -> Bool { p.r >= 0 && p.r < size && p.c >= 0 && p.c < size }
    private func neighbors(of p: Point) -> [Point] { return [Point(r: p.r - 1, c: p.c), Point(r: p.r + 1, c: p.c), Point(r: p.r, c: p.c - 1), Point(r: p.r, c: p.c + 1)].filter(inBounds) }
    
    private func collectGroup(board: [[Stone]], start: Point) -> [Point] {
        let color = board[start.r][start.c]
        guard color != .empty else { return [] }
        var visited: Set<Point> = [start]; var stack: [Point] = [start]
        while let p = stack.popLast() {
            for nb in neighbors(of: p) {
                if board[nb.r][nb.c] == color, !visited.contains(nb) {
                    visited.insert(nb); stack.append(nb)
                }
            }
        }
        return Array(visited)
    }
    
    private func liberties(of group: [Point], board: [[Stone]]) -> Int {
        var libs: Set<Point> = []
        for p in group { for nb in neighbors(of: p) { if board[nb.r][nb.c] == .empty { libs.insert(nb) } } }
        return libs.count
    }
    
    private static func hashBoard(_ board: [[Stone]]) -> String {
        var s = ""
        for r in 0..<board.count { for c in 0..<board.count { s.append(Character(UnicodeScalar(48 + board[r][c].rawValue)!)) } }
        return s
    }
}
