import Foundation

enum MistakeCategory: String, Codable, CaseIterable, Sendable {
    case solid = "稳健"
    case direction = "方向判断"
    case slowMove = "缓手"
    case missedUrgency = "先后手判断"
    case overplay = "贪大/过分"
    case safety = "安定问题"
    case lifeAndDeath = "死活误判"
    case endgame = "官子价值"
    case localResponse = "局部应对"
}

enum MistakeSeverity: String, Codable, Comparable, Sendable {
    case solid = "好棋"
    case slight = "可改进"
    case inaccuracy = "小失误"
    case mistake = "明显失误"
    case blunder = "败着"

    var priority: Int {
        switch self {
        case .solid: return 0
        case .slight: return 1
        case .inaccuracy: return 2
        case .mistake: return 3
        case .blunder: return 4
        }
    }

    static func < (lhs: MistakeSeverity, rhs: MistakeSeverity) -> Bool {
        lhs.priority < rhs.priority
    }
}

struct TeachingFeedback: Identifiable, Codable, Equatable, Sendable {
    var id: Int { turn }

    let turn: Int
    let player: Stone
    let category: MistakeCategory
    let severity: MistakeSeverity
    let winrateDrop: Double
    let scoreLoss: Double
    let playedMove: String
    let bestMove: String?
    let candidateRank: Int?
    let summary: String
    let betterMoveReason: String
    let checklist: [String]
}

struct TeachingFeedbackAnalyzer: Sendable {
    static func feedback(for turn: Int, moves: [Move], analyses: [Int: MoveAnalysis], boardSize: Int) -> TeachingFeedback? {
        guard turn > 0,
              turn <= moves.count,
              let current = analyses[turn],
              let previous = analyses[turn - 1] else {
            return nil
        }

        let move = moves[turn - 1]
        let winrateDrop = max(0, move.player == .black ? previous.winrate - current.winrate : current.winrate - previous.winrate)
        let scoreLoss = max(0, move.player == .black ? previous.scoreLead - current.scoreLead : current.scoreLead - previous.scoreLead)
        let playedMove = move.kind.gtpString(boardSize: boardSize)
        let bestMove = previous.bestMove?.toGTP(boardSize: boardSize)
        let candidateRank = previous.candidateMoves.first { $0.move.uppercased() == playedMove.uppercased() }?.order
        let severity = severity(for: winrateDrop)
        let category = category(
            turn: turn,
            totalMoves: moves.count,
            move: move,
            severity: severity,
            scoreLoss: scoreLoss,
            candidateRank: candidateRank,
            bestMove: bestMove,
            boardSize: boardSize
        )

        return TeachingFeedback(
            turn: turn,
            player: move.player,
            category: category,
            severity: severity,
            winrateDrop: winrateDrop,
            scoreLoss: scoreLoss,
            playedMove: playedMove,
            bestMove: bestMove,
            candidateRank: candidateRank,
            summary: summary(category: category, severity: severity, winrateDrop: winrateDrop, scoreLoss: scoreLoss, candidateRank: candidateRank),
            betterMoveReason: betterMoveReason(category: category, bestMove: bestMove, candidateRank: candidateRank),
            checklist: checklist(for: category)
        )
    }

    static func keyFeedbacks(moves: [Move], analyses: [Int: MoveAnalysis], boardSize: Int, limit: Int = 6) -> [TeachingFeedback] {
        (1...moves.count)
            .compactMap { feedback(for: $0, moves: moves, analyses: analyses, boardSize: boardSize) }
            .filter { $0.severity >= .inaccuracy }
            .sorted {
                if $0.severity == $1.severity { return $0.winrateDrop > $1.winrateDrop }
                return $0.severity > $1.severity
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func severity(for winrateDrop: Double) -> MistakeSeverity {
        switch winrateDrop {
        case 0..<0.02: return .solid
        case 0.02..<0.05: return .slight
        case 0.05..<0.10: return .inaccuracy
        case 0.10..<0.20: return .mistake
        default: return .blunder
        }
    }

    private static func category(
        turn: Int,
        totalMoves: Int,
        move: Move,
        severity: MistakeSeverity,
        scoreLoss: Double,
        candidateRank: Int?,
        bestMove: String?,
        boardSize: Int
    ) -> MistakeCategory {
        guard severity != .solid else { return .solid }
        if case .pass = move.kind { return .endgame }

        let boardArea = boardSize * boardSize
        let lateGameThreshold = max(80, Int(Double(boardArea) * 0.45))
        if turn > lateGameThreshold { return .endgame }

        if candidateRank == nil, severity >= .mistake { return .direction }
        if scoreLoss >= 6.0 { return .direction }
        if candidateRank.map({ $0 >= 3 }) ?? false { return .slowMove }
        if bestMove != nil, severity >= .mistake { return .localResponse }
        return .missedUrgency
    }

    private static func summary(
        category: MistakeCategory,
        severity: MistakeSeverity,
        winrateDrop: Double,
        scoreLoss: Double,
        candidateRank: Int?
    ) -> String {
        guard severity != .solid else {
            return "这手棋没有造成明显损失，可以作为当前局面的正常应手。"
        }

        let wrText = String(format: "%.1f%%", winrateDrop * 100)
        let scoreText = String(format: "%.1f", scoreLoss)
        let rankText = candidateRank.map { "KataGo 候选第 \($0) 位" } ?? "未进入前三候选"
        return "\(severity.rawValue)：主要问题是\(category.rawValue)，胜率约损失 \(wrText)，目差约损失 \(scoreText) 目，\(rankText)。"
    }

    private static func betterMoveReason(category: MistakeCategory, bestMove: String?, candidateRank: Int?) -> String {
        guard let bestMove else {
            return "当前没有足够的最佳点数据，建议先对照候选点和胜率曲线确认这手的局部目的。"
        }

        switch category {
        case .solid:
            return "当前选择可以接受，继续关注后续先手和棋形效率。"
        case .direction:
            return "更好的方向通常是先处理全局价值最高的区域。此处优先参考 \(bestMove)，它更符合当前胜率和目差的主线。"
        case .slowMove:
            return "\(bestMove) 更主动，通常能保留先手或制造更直接的压力；实战手效率偏低。"
        case .missedUrgency:
            return "\(bestMove) 更急，说明此处存在对双方影响更大的先手点，应该先处理再考虑普通大场。"
        case .overplay:
            return "\(bestMove) 更稳健，优先保证棋形和后续手段，避免把局面下重。"
        case .safety:
            return "\(bestMove) 更重视自身安定，先消除弱点再谈进攻或围空。"
        case .lifeAndDeath:
            return "\(bestMove) 更贴近局部死活要点，先确认眼位、气紧和连接。"
        case .endgame:
            return "\(bestMove) 的官子价值更高，复盘时要比较双方后续先手和目数收益。"
        case .localResponse:
            return "\(bestMove) 是更强的局部应对，说明实战手在形状、次序或局部攻防上有偏差。"
        }
    }

    private static func checklist(for category: MistakeCategory) -> [String] {
        switch category {
        case .solid:
            return ["确认下一手对方最强反击", "保留先手意识", "不要因为局部顺利而脱离全局"]
        case .direction:
            return ["先比较四个角边的急所", "判断哪边棋更弱", "问自己这手是在围空、攻棋还是补弱"]
        case .slowMove:
            return ["这手是否有先手价值", "对方是否有更急的反击点", "能否用更主动的手法达到同样目的"]
        case .missedUrgency:
            return ["先找双方断点和弱棋", "检查对方下一手的最大威胁", "普通大场之前先处理急所"]
        case .overplay:
            return ["自己的棋是否已经安定", "强攻后有没有退路", "收益是否值得承担风险"]
        case .safety:
            return ["自己的弱棋有几口气", "是否需要先连接或做眼", "对方攻击能否连续获利"]
        case .lifeAndDeath:
            return ["先数气", "确认眼位真假", "检查扑、倒扑、接不归等手筋"]
        case .endgame:
            return ["比较双方后续先手", "估算当前手实际目数", "优先走双先或逆收大官子"]
        case .localResponse:
            return ["先看局部形状弱点", "确认应手次序", "比较候选点的主变差异"]
        }
    }
}

private extension MoveKind {
    func gtpString(boardSize: Int) -> String {
        switch self {
        case .place(let point): return point.toGTP(boardSize: boardSize)
        case .pass: return "pass"
        }
    }
}
