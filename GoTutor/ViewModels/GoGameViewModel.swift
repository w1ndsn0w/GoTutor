import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers
@MainActor
final class GoGameViewModel: ObservableObject {
    let size: Int
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
        didSet { if isAIBattleMode && currentPlayer == aiPlayerColor { scheduleAnalysis() } }
    }
    @Published var aiPlayerColor: Stone = .white {
        didSet {
            if isAIBattleMode && currentPlayer == aiPlayerColor {
                scheduleAnalysis()
            }
        }
    }
    // MARK: - 导师模式核心状态
    @Published var isTutorMode: Bool = false {
        didSet {
            if isTutorMode {
                checkedTurnForTutor = -1
                isAnalyzingTutor = true
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
        didSet { if showRealTimeTerritory { isEndGameScoring = false }; updateTerritory() }
    }
    @Published var isEndGameScoring: Bool = false {
        didSet {
            if isEndGameScoring { showRealTimeTerritory = false; if let own = latestOwnership { seedDeadStones(ownership: own) } }
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
    
    private var snapshots: [GameSnapshot] = []
    private var positionHistory: Set<String> = []
    private var currentFileURL: URL? = nil
    
    // 【核心】接入单例引擎
    private let aiEngine = KataGoWrapper.shared()
    private var latestOwnership: [Double]? = nil
    private var analysisTimer: DispatchWorkItem?
    private var expectedBatchResponses = 0
    private var receivedBatchResponses = 0
    private var notificationTask: Task<Void, Never>?
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
        guard let modelPath = Bundle.main.path(forResource: "model", ofType: "bin.gz"),
              let configPath = Bundle.main.path(forResource: "analysis", ofType: "cfg") else {
            print("❌ 找不到模型文件或 analysis.cfg 配置！")
            return
        }
        let _ = aiEngine.setEngineWithModel(modelPath, config: configPath)
    }
    
    // 🚨 修正：将 handleKataGoJSON 独立出来，不再嵌套在别的方法内部
    private func handleKataGoJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let response = try JSONDecoder().decode(KataGoResponse.self, from: data)
            
            // 核心防御网：必须带着我的专属 UUID，否则丢弃数据
            guard let responseId = response.id, responseId.hasPrefix(self.gameId) else { return }
            
            let turn = response.turnNumber ?? 0
            
            if responseId.hasSuffix("batch_review") {
                self.receivedBatchResponses += 1
                let progress = min(1.0, Double(self.receivedBatchResponses) / Double(max(1, self.expectedBatchResponses)))
                self.analysisProgress = progress
                if progress >= 1.0 { self.autoSaveToCurrentFile() }
            }
            if let info = response.rootInfo, let wr = info.winrate, let sl = info.scoreLead {
                var bestMovePt: Point? = nil
                var candidates: [CandidateMove] = []
                
                if let moveInfos = response.moveInfos {
                    // 1. 提取第一名作为 bestMove
                    if let bestMoveStr = moveInfos.first?.move {
                        bestMovePt = self.fromGTPCoordinate(bestMoveStr)
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
            
            if self.isAIBattleMode && turn == self.currentTurn && self.currentPlayer == self.aiPlayerColor {
                if let bestMove = response.moveInfos?.first?.move {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if bestMove.lowercased() == "pass" { self.pass() } else if let pt = self.fromGTPCoordinate(bestMove) { self.place(atRow: pt.r, col: pt.c) }
                    }
                }
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
            
            if let actual = actualPt, let best = previous.bestMove, actual != best && wrDrop > 0.05 {
                let wrPercent = String(format: "%.1f%%", wrDrop * 100)
                let slPoints = String(format: "%.1f", slDrop)
                let rating = wrDrop > 0.20 ? "惊天大恶手 📉" : "缓手/失误 ⚠️"
                
                blunderMessage = "\(rating)\n胜率暴跌 \(wrPercent) (亏损 \(slPoints) 目)"
                previousBestMove = best
                tutorExplanation = ""
                isTutorThinking = true
                
                let colorStr = lastPlayer == .black ? "黑棋" : "白棋"
                let actualStr = toGTPCoordinate(r: actual.r, c: actual.c)
                let bestStr = toGTPCoordinate(r: best.r, c: best.c)
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
        restore(from: snap); currentTurn = moves.count
        resetTutorUIForNewMove(isHuman: true)
        scheduleAnalysis()
    }
    
    func reset() {
        board = Array(repeating: Array(repeating: .empty, count: size), count: size)
        currentPlayer = .black; capturesBlack = 0; capturesWhite = 0; consecutivePasses = 0; isGameOver = false; moves = []; lastMove = nil; lastIllegalReason = nil
        snapshots = []; positionHistory = [Self.hashBoard(board)]
        showRealTimeTerritory = false; isEndGameScoring = false; latestOwnership = nil; moveAnalyses = [:]
        currentTurn = 0; isReviewMode = false; analysisProgress = 1.0
        
        resetTutorUIForNewMove(isHuman: true)
        isAnalyzingTutor = false
        scheduleAnalysis()
    }
    
    func toggleDeadStone(atRow r: Int, col c: Int) {
        guard isEndGameScoring else { return }
        let p = Point(r: r, c: c); guard board[r][c] != .empty else { return }
        let group = collectGroup(board: board, start: p)
        if deadStones.contains(p) { deadStones.subtract(group) } else { deadStones.formUnion(group) }
        updateTerritory()
    }
    
    func loadGame(from url: URL) {
        self.currentFileURL = url
        do {
            let data = try Data(contentsOf: url); let savedGame = try JSONDecoder().decode(SavedGame.self, from: data)
            self.moves = savedGame.moves; self.moveAnalyses = savedGame.analyses; self.isReviewMode = true
            
            if !self.moveAnalyses.isEmpty && self.moveAnalyses.count > self.moves.count {
                self.analysisProgress = 1.0
            } else {
                self.analysisProgress = 0.0
                requestBatchAnalysis()
            }
            setTurn(0)
        } catch { print("❌ 读取失败: \(error)") }
    }
    
    func setTurn(_ turn: Int) {
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
                board[p.r][p.c] = color; var capturedPoints: [Point] = []
                for nb in neighbors(of: p) { if board[nb.r][nb.c] == color.opponent { let group = collectGroup(board: board, start: nb); if liberties(of: group, board: board) == 0 { capturedPoints.append(contentsOf: group) } } }
                for cp in capturedPoints { board[cp.r][cp.c] = .empty }; if color == .black { capturesBlack += capturedPoints.count } else { capturesWhite += capturedPoints.count }
            }
            currentPlayer = color.next; lastMove = move
        }
    }
    
    func generateSaveData() -> SavedGame {
        return SavedGame(size: size, date: Date(), moves: moves, analyses: moveAnalyses)
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
    
    private func fromGTPCoordinate(_ gtp: String) -> Point? {
        let upper = gtp.uppercased(); guard upper.count >= 2 else { return nil }
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"]
        guard let c = letters.firstIndex(of: String(upper.prefix(1))), let number = Int(upper.dropFirst()) else { return nil }
        return Point(r: size - number, c: c)
    }
    
    private func toGTPCoordinate(r: Int, c: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"]
        return "\(letters[c])\(size - r)"
    }
    private var analysisTask: Task<Void, Never>?

    private func scheduleAnalysis() {
        analysisTask?.cancel()
        if isAIBattleMode && currentPlayer == aiPlayerColor {
            requestSingleAnalysis()
        } else {
            analysisTask = Task {
                // 等待 3 秒 (Swift 6 可以直接用 .seconds(3))
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self.requestSingleAnalysis() // 安全调用，继承了 @MainActor
            }
        }
    }
    
    // MARK: - 网络请求
    private func requestSingleAnalysis() {
        var gtpMoves: [[String]] = []
        for move in moves {
            let playerStr = move.player == .black ? "B" : "W"
            switch move.kind {
            case .place(let p): gtpMoves.append([playerStr, toGTPCoordinate(r: p.r, c: p.c)])
            case .pass: gtpMoves.append([playerStr, "pass"])
            }
        }
        
        // 🚨 修正：此处保持 query 格式，并戴上身份证 gameId
        let queryDict: [String: Any] = [
            "id": "\(gameId)_query_\(moves.count)",
            "moves": gtpMoves,
            "rules": "chinese",
            "boardXSize": size,
            "boardYSize": size,
            "analyzeTurns": [gtpMoves.count],
            "maxVisits": 50,
            "includeOwnership": true
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: queryDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            aiEngine.sendQuery(jsonString)
        }
    }
    
    private func requestBatchAnalysis() {
        var gtpMoves: [[String]] = []
        for move in moves {
            let playerStr = move.player == .black ? "B" : "W"
            switch move.kind {
            case .place(let p): gtpMoves.append([playerStr, toGTPCoordinate(r: p.r, c: p.c)])
            case .pass: gtpMoves.append([playerStr, "pass"])
            }
        }
        
        expectedBatchResponses = moves.count + 1
        receivedBatchResponses = 0
        analysisProgress = 0.0
        
        // 🚨 修正：修复了刚才粘贴错的 analyzeTurns 和 id
        let queryDict: [String: Any] = [
            "id": "\(gameId)_batch_review",
            "moves": gtpMoves,
            "rules": "chinese",
            "boardXSize": size,
            "boardYSize": size,
            "analyzeTurns": Array(0...moves.count), // 批量分析 0 到最后一步
            "maxVisits": 50,
            "includeOwnership": true
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: queryDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            aiEngine.sendQuery(jsonString)
        }
    }
    
    // MARK: - 计目系统
    private func updateTerritory() {
        guard showRealTimeTerritory || isEndGameScoring else {
            currentAnalysis = nil; deadStones.removeAll(); return
        }
        guard let ownership = latestOwnership else { return }
        
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
        let gameData = SavedGame(size: size, date: Date(), moves: moves, analyses: moveAnalyses)
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
