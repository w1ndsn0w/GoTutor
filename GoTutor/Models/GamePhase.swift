import SwiftUI

enum GamePhase: String, CaseIterable, Identifiable, Sendable {
    case opening
    case middleGame
    case endgame
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opening: return "布局"
        case .middleGame: return "中盘"
        case .endgame: return "官子"
        case .finished: return "终局"
        }
    }

    var subtitle: String {
        switch self {
        case .opening: return "抢角占边，搭建地盘与势力框架"
        case .middleGame: return "侵分打入，处理攻防和孤棋"
        case .endgame: return "边界定型后计算大小官子"
        case .finished: return "停手确认，进入数子或点目"
        }
    }

    var iconName: String {
        switch self {
        case .opening: return "scope"
        case .middleGame: return "bolt.horizontal"
        case .endgame: return "sum"
        case .finished: return "checkmark.seal"
        }
    }

    var tint: Color {
        switch self {
        case .opening: return .blue
        case .middleGame: return .orange
        case .endgame: return .purple
        case .finished: return .green
        }
    }
}

struct GamePhaseSpan: Identifiable, Sendable {
    let phase: GamePhase
    let startTurn: Int
    let endTurn: Int

    var id: GamePhase { phase }

    var turnText: String {
        if startTurn == endTurn { return "第 \(startTurn) 手" }
        return "\(startTurn)-\(endTurn) 手"
    }
}

struct GamePhaseClassifier: Sendable {
    let totalMoves: Int
    let boardSize: Int
    let moves: [Move]
    let analyses: [Int: MoveAnalysis]
    let analysisProgress: Double

    init(
        totalMoves: Int,
        boardSize: Int,
        moves: [Move] = [],
        analyses: [Int: MoveAnalysis] = [:],
        analysisProgress: Double = 1.0
    ) {
        self.totalMoves = totalMoves
        self.boardSize = boardSize
        self.moves = moves
        self.analyses = analyses
        self.analysisProgress = analysisProgress
    }

    var isAIRefined: Bool {
        analysisProgress >= 1.0 && analysisCoverage >= 0.65
    }

    var methodText: String {
        isAIRefined ? "AI校准" : "手数估计"
    }

    var spans: [GamePhaseSpan] {
        guard totalMoves > 0 else {
            return [GamePhaseSpan(phase: .opening, startTurn: 0, endTurn: 0)]
        }

        let finishedStart = finishedStartTurn
        let mainEnd = max(0, finishedStart - 1)
        guard mainEnd >= 1 else {
            return [GamePhaseSpan(phase: .finished, startTurn: finishedStart, endTurn: totalMoves)]
        }

        let openingEnd = min(mainEnd, openingEndTurn)
        let endgameStart = min(max(openingEnd + 1, endgameStartTurn), mainEnd)
        let middleEnd = max(openingEnd, endgameStart - 1)

        var result = [GamePhaseSpan(phase: .opening, startTurn: 1, endTurn: openingEnd)]

        if middleEnd >= openingEnd + 1 {
            result.append(GamePhaseSpan(phase: .middleGame, startTurn: openingEnd + 1, endTurn: middleEnd))
        }

        if mainEnd >= endgameStart {
            result.append(GamePhaseSpan(phase: .endgame, startTurn: endgameStart, endTurn: mainEnd))
        }

        result.append(GamePhaseSpan(phase: .finished, startTurn: totalMoves, endTurn: totalMoves))
        return result
    }

    func phase(for turn: Int) -> GamePhase {
        guard totalMoves > 0 else { return .opening }
        if turn >= finishedStartTurn { return .finished }
        if turn <= openingEndTurn { return .opening }
        if turn >= endgameStartTurn { return .endgame }
        return .middleGame
    }

    func span(for phase: GamePhase) -> GamePhaseSpan? {
        spans.first { $0.phase == phase }
    }

    private var openingEndTurn: Int {
        if let aiOpeningEndTurn {
            return aiOpeningEndTurn
        }

        let conventionalOpening = boardSize >= 19 ? 50 : max(18, boardSize * 2)
        let proportionalOpening = max(12, Int(Double(totalMoves) * 0.22))
        return max(1, min(totalMoves, min(conventionalOpening, max(30, proportionalOpening))))
    }

    private var endgameStartTurn: Int {
        if let aiEndgameStartTurn {
            return aiEndgameStartTurn
        }

        guard totalMoves > 0 else { return 0 }
        let conventionalEndgame = boardSize >= 19 ? 170 : max(45, boardSize * 5)
        let proportionalEndgame = Int(Double(totalMoves) * 0.72)
        return max(openingEndTurn + 1, min(totalMoves, min(conventionalEndgame, max(proportionalEndgame, totalMoves - 60))))
    }

    private var finishedStartTurn: Int {
        guard totalMoves > 0 else { return 0 }
        if totalMoves >= 2,
           moves.indices.contains(totalMoves - 2),
           moves.indices.contains(totalMoves - 1),
           moves[totalMoves - 2].isPass,
           moves[totalMoves - 1].isPass {
            return totalMoves - 1
        }
        return totalMoves
    }

    private var analysisCoverage: Double {
        guard totalMoves > 0 else { return 0 }
        let analyzedTurns = (0...totalMoves).filter { analyses[$0] != nil }.count
        return min(1.0, Double(analyzedTurns) / Double(totalMoves + 1))
    }

    private var aiOpeningEndTurn: Int? {
        guard isAIRefined, totalMoves >= 40 else { return nil }

        let minimumOpening = boardSize >= 19 ? 30 : max(10, boardSize + 2)
        let maximumOpening = min(totalMoves, boardSize >= 19 ? 65 : max(24, boardSize * 3))
        guard minimumOpening < maximumOpening else { return nil }

        for turn in minimumOpening...maximumOpening {
            let metrics = windowMetrics(start: turn, length: 10)
            if metrics.scoreSwing >= 0.75 || metrics.winrateSwing >= 0.028 {
                return max(1, min(totalMoves, turn - 1))
            }
        }

        return nil
    }

    private var aiEndgameStartTurn: Int? {
        guard isAIRefined, totalMoves >= 80 else { return nil }

        let earliest = max(openingEndTurn + 24, Int(Double(totalMoves) * 0.58))
        let latest = max(earliest, finishedStartTurn - 8)
        guard earliest <= latest else { return nil }

        for turn in earliest...latest {
            let metrics = windowMetrics(start: turn, length: 14)
            let isTerritoryStable = metrics.ownershipCertainty >= 0.60
            let isScoreSettled = metrics.scoreSwing <= 0.55 && metrics.winrateSwing <= 0.018

            if isTerritoryStable && isScoreSettled {
                return turn
            }
        }

        return nil
    }

    private func windowMetrics(start: Int, length: Int) -> PhaseWindowMetrics {
        let end = min(totalMoves, start + length)
        guard start < end else { return PhaseWindowMetrics(scoreSwing: 0, winrateSwing: 0, ownershipCertainty: 0) }

        var scoreSwings: [Double] = []
        var winrateSwings: [Double] = []
        var ownershipCertainties: [Double] = []

        for turn in (start + 1)...end {
            if let previous = analyses[turn - 1], let current = analyses[turn] {
                scoreSwings.append(abs(current.scoreLead - previous.scoreLead))
                winrateSwings.append(abs(current.winrate - previous.winrate))
            }

            if let ownership = analyses[turn]?.ownership, !ownership.isEmpty {
                let certainty = ownership.reduce(0.0) { $0 + abs($1) } / Double(ownership.count)
                ownershipCertainties.append(certainty)
            }
        }

        return PhaseWindowMetrics(
            scoreSwing: scoreSwings.average,
            winrateSwing: winrateSwings.average,
            ownershipCertainty: ownershipCertainties.average
        )
    }
}

private struct PhaseWindowMetrics {
    let scoreSwing: Double
    let winrateSwing: Double
    let ownershipCertainty: Double
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension Move {
    var isPass: Bool {
        if case .pass = kind { return true }
        return false
    }
}
