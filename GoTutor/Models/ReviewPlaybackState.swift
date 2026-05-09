import Foundation

struct ReviewTurnSnapshot: Equatable, Sendable {
    let board: [[Stone]]
    let currentPlayer: Stone
    let capturesBlack: Int
    let capturesWhite: Int
    let consecutivePasses: Int
    let isGameOver: Bool
    let lastMove: Move?
}

struct ReviewPanelState: Equatable, Sendable {
    let currentTurn: Int
    let boardSize: Int
    let analysisProgress: Double
    let currentAnalysis: MoveAnalysis?
    let currentFeedback: TeachingFeedback?
    let keyFeedbacks: [TeachingFeedback]

    static let empty = ReviewPanelState(
        currentTurn: 0,
        boardSize: 19,
        analysisProgress: 1.0,
        currentAnalysis: nil,
        currentFeedback: nil,
        keyFeedbacks: []
    )
}

struct ReviewPlaybackState: Sendable {
    private(set) var boardSize: Int = 19
    private(set) var moves: [Move] = []
    private(set) var analyses: [Int: MoveAnalysis] = [:]

    private var turnSnapshots: [ReviewTurnSnapshot] = []
    private var keyFeedbackCache: [Int: [TeachingFeedback]] = [:]

    var hasSnapshots: Bool {
        !turnSnapshots.isEmpty
    }

    mutating func reset() {
        boardSize = 19
        moves = []
        analyses = [:]
        turnSnapshots = []
        keyFeedbackCache = [:]
    }

    mutating func configure(boardSize: Int, moves: [Move], analyses: [Int: MoveAnalysis]) {
        self.boardSize = boardSize
        self.moves = moves
        self.analyses = analyses
        self.turnSnapshots = Self.buildSnapshots(boardSize: boardSize, moves: moves)
        self.keyFeedbackCache = [:]
    }

    mutating func updateAnalyses(_ analyses: [Int: MoveAnalysis]) {
        self.analyses = analyses
        self.keyFeedbackCache = [:]
    }

    func snapshot(for turn: Int) -> ReviewTurnSnapshot? {
        guard turnSnapshots.indices.contains(turn) else { return nil }
        return turnSnapshots[turn]
    }

    func teachingFeedback(for turn: Int) -> TeachingFeedback? {
        TeachingFeedbackAnalyzer.feedback(for: turn, moves: moves, analyses: analyses, boardSize: boardSize)
    }

    mutating func keyTeachingFeedbacks(limit: Int = 6) -> [TeachingFeedback] {
        if let cached = keyFeedbackCache[limit] {
            return cached
        }

        let feedbacks = TeachingFeedbackAnalyzer.keyFeedbacks(
            moves: moves,
            analyses: analyses,
            boardSize: boardSize,
            limit: limit
        )
        keyFeedbackCache[limit] = feedbacks
        return feedbacks
    }

    mutating func panelState(currentTurn: Int, analysisProgress: Double) -> ReviewPanelState {
        ReviewPanelState(
            currentTurn: currentTurn,
            boardSize: boardSize,
            analysisProgress: analysisProgress,
            currentAnalysis: analyses[currentTurn],
            currentFeedback: teachingFeedback(for: currentTurn),
            keyFeedbacks: keyTeachingFeedbacks()
        )
    }

    static func buildSnapshots(boardSize: Int, moves: [Move]) -> [ReviewTurnSnapshot] {
        var replayBoard = Array(repeating: Array(repeating: Stone.empty, count: boardSize), count: boardSize)
        var replayCurrentPlayer = Stone.black
        var replayCapturesBlack = 0
        var replayCapturesWhite = 0
        var replayConsecutivePasses = 0
        var replayIsGameOver = false
        var replayLastMove: Move?
        var snapshots = [
            ReviewTurnSnapshot(
                board: replayBoard,
                currentPlayer: replayCurrentPlayer,
                capturesBlack: replayCapturesBlack,
                capturesWhite: replayCapturesWhite,
                consecutivePasses: replayConsecutivePasses,
                isGameOver: replayIsGameOver,
                lastMove: replayLastMove
            )
        ]

        for move in moves {
            let color = move.player
            switch move.kind {
            case .place(let point):
                if point.isOnBoard(size: boardSize) {
                    replayBoard[point.r][point.c] = color
                    let capturedPoints = capturedStones(afterPlacing: point, color: color, board: replayBoard, boardSize: boardSize)
                    for capturedPoint in capturedPoints {
                        replayBoard[capturedPoint.r][capturedPoint.c] = .empty
                    }
                    if color == .black {
                        replayCapturesBlack += capturedPoints.count
                    } else {
                        replayCapturesWhite += capturedPoints.count
                    }
                }
                replayConsecutivePasses = 0
            case .pass:
                replayConsecutivePasses += 1
            }

            replayCurrentPlayer = color.next
            replayLastMove = move
            replayIsGameOver = replayConsecutivePasses >= 2
            snapshots.append(
                ReviewTurnSnapshot(
                    board: replayBoard,
                    currentPlayer: replayCurrentPlayer,
                    capturesBlack: replayCapturesBlack,
                    capturesWhite: replayCapturesWhite,
                    consecutivePasses: replayConsecutivePasses,
                    isGameOver: replayIsGameOver,
                    lastMove: replayLastMove
                )
            )
        }

        return snapshots
    }

    private static func capturedStones(afterPlacing point: Point, color: Stone, board: [[Stone]], boardSize: Int) -> [Point] {
        var capturedPoints: [Point] = []
        for neighbor in neighbors(of: point, boardSize: boardSize) where board[neighbor.r][neighbor.c] == color.opponent {
            let group = collectGroup(board: board, start: neighbor, boardSize: boardSize)
            if liberties(of: group, board: board, boardSize: boardSize) == 0 {
                capturedPoints.append(contentsOf: group)
            }
        }
        return capturedPoints
    }

    private static func collectGroup(board: [[Stone]], start: Point, boardSize: Int) -> [Point] {
        let color = board[start.r][start.c]
        guard color != .empty else { return [] }

        var visited: Set<Point> = [start]
        var stack = [start]

        while let point = stack.popLast() {
            for neighbor in neighbors(of: point, boardSize: boardSize) where board[neighbor.r][neighbor.c] == color && !visited.contains(neighbor) {
                visited.insert(neighbor)
                stack.append(neighbor)
            }
        }

        return Array(visited)
    }

    private static func liberties(of group: [Point], board: [[Stone]], boardSize: Int) -> Int {
        var liberties = Set<Point>()
        for point in group {
            for neighbor in neighbors(of: point, boardSize: boardSize) where board[neighbor.r][neighbor.c] == .empty {
                liberties.insert(neighbor)
            }
        }
        return liberties.count
    }

    private static func neighbors(of point: Point, boardSize: Int) -> [Point] {
        [
            Point(r: point.r - 1, c: point.c),
            Point(r: point.r + 1, c: point.c),
            Point(r: point.r, c: point.c - 1),
            Point(r: point.r, c: point.c + 1)
        ].filter { $0.isOnBoard(size: boardSize) }
    }
}
