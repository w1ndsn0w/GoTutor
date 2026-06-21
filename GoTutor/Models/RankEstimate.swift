import Foundation

enum RankEstimateConfidence: String, Codable, Sendable {
    case low = "低"
    case medium = "中"
    case high = "高"
}

enum RankMistakeType: String, Codable, CaseIterable, Sendable {
    case openingDirection = "布局方向问题"
    case bigPointJudgement = "大场判断问题"
    case attackDefensePriority = "攻防优先级问题"
    case safety = "补棋 / 安定问题"
    case lifeAndDeath = "死活 / 手筋问题"
    case fightingReading = "战斗计算问题"
    case endgame = "官子 / 收官问题"
    case tooConservative = "过度保守"
    case tooAggressive = "过度激进"
    case unclear = "不明原因 / 待进一步分析"
}

struct ProfileScore: Codable, Equatable, Sendable, Identifiable {
    var id: String { profile }

    let profile: String
    let similarityScore: Double
    let sampleCount: Int
}

struct RankPhaseSummary: Codable, Equatable, Sendable {
    let title: String
    let moveCount: Int
    let averageScoreLoss: Double
    let totalScoreLoss: Double
    let majorMistakeCount: Int

    var summaryText: String {
        guard moveCount > 0 else { return "样本不足" }
        if averageScoreLoss >= 3.0 { return "波动较大，建议重点复盘" }
        if averageScoreLoss >= 1.4 { return "有一定损失，需要针对训练" }
        return "整体较稳"
    }
}

struct PhaseBreakdown: Codable, Equatable, Sendable {
    let opening: RankPhaseSummary
    let middleGame: RankPhaseSummary
    let endgame: RankPhaseSummary
}

struct MistakeBreakdown: Codable, Equatable, Sendable, Identifiable {
    var id: RankMistakeType { type }

    let type: RankMistakeType
    let count: Int
    let totalScoreLoss: Double
    let explanation: String
}

struct KeyMistake: Codable, Equatable, Sendable, Identifiable {
    var id: Int { turn }

    let turn: Int
    let playedMove: String
    let recommendedMove: String?
    let scoreDrop: Double
    let winrateDrop: Double
    let mistakeType: RankMistakeType
    let shortReason: String
}

struct RankEstimateReport: Codable, Equatable, Sendable {
    let targetPlayer: Stone
    let estimatedRange: String
    let mostSimilarProfile: String?
    let confidence: RankEstimateConfidence
    let confidenceReason: String
    let profileScores: [ProfileScore]
    let averageScoreLoss: Double
    let blunderCount: Int
    let phaseBreakdown: PhaseBreakdown
    let mistakeBreakdown: [MistakeBreakdown]
    let keyMistakes: [KeyMistake]
    let recommendations: [String]
    let generatedAt: Date
    let usedHumanSL: Bool
    let humanSLMessage: String
    let disclaimer: String
}

enum RankEstimateRunState: Sendable {
    case idle
    case running(progress: Double, message: String)
    case completed(RankEstimateReport)
    case failed(String)
}

enum RankEstimateAnalyzer {
    static let supportedHumanSLProfiles = [
        "rank_20k",
        "rank_15k",
        "rank_10k",
        "rank_5k",
        "rank_1k",
        "rank_1d",
        "rank_3d",
        "rank_5d",
        "rank_9d"
    ]

    static func profileDisplayName(_ profile: String) -> String {
        switch profile {
        case "rank_20k": return "业余1段"
        case "rank_15k": return "业余2段"
        case "rank_10k": return "业余3段"
        case "rank_5k": return "业余4段"
        case "rank_1k": return "业余5段"
        case "rank_1d": return "业余6段"
        case "rank_3d": return "业余7段"
        case "rank_5d": return "业余8段"
        case "rank_9d": return "职业九段"
        default: return profile
        }
    }

    static func humanSLTargetTurns(targetPlayer: Stone, moves: [Move]) -> [Int] {
        moves.enumerated()
            .filter { $0.element.player == targetPlayer && !$0.element.isPassMove }
            .map { $0.offset + 1 }
    }

    static func representativeTurns(
        targetPlayer: Stone,
        moves: [Move],
        analyses: [Int: MoveAnalysis],
        boardSize: Int,
        limit: Int = 4
    ) -> [Int] {
        guard !moves.isEmpty, limit > 0 else { return [] }
        let classifier = GamePhaseClassifier(
            totalMoves: moves.count,
            boardSize: boardSize,
            moves: moves,
            analyses: analyses,
            analysisProgress: analysisCoverage(totalMoves: moves.count, analyses: analyses)
        )

        let evaluations = moveEvaluations(targetPlayer: targetPlayer, moves: moves, analyses: analyses, boardSize: boardSize, classifier: classifier)
        let ranked = evaluations
            .sorted {
                if abs($0.scoreLoss - $1.scoreLoss) > 0.3 { return $0.scoreLoss > $1.scoreLoss }
                return $0.turn < $1.turn
            }
        let targetTurns = moves.enumerated()
            .filter { $0.element.player == targetPlayer && !$0.element.isPassMove }
            .map { $0.offset + 1 }

        var selected: [Int] = []
        for phase in [GamePhase.opening, .middleGame, .endgame] {
            let turnsInPhase = targetTurns.filter { classifier.phase(for: $0) == phase }
            if !turnsInPhase.isEmpty {
                selected.append(turnsInPhase[turnsInPhase.count / 2])
            }
        }

        for evaluation in ranked.prefix(2) where selected.count < limit && !selected.contains(evaluation.turn) {
            selected.append(evaluation.turn)
        }

        if selected.count < limit {
            let stride = max(1, targetTurns.count / max(1, limit))
            for turn in targetTurns.enumerated().filter({ $0.offset % stride == 0 }).map(\.element) where selected.count < limit && !selected.contains(turn) {
                selected.append(turn)
            }
        }

        return selected.sorted()
    }

    static func makeReport(
        targetPlayer: Stone,
        moves: [Move],
        analyses: [Int: MoveAnalysis],
        boardSize: Int,
        profileScores: [ProfileScore],
        humanSLAvailable: Bool,
        humanSLTimedOut: Bool
    ) -> RankEstimateReport {
        let coverage = analysisCoverage(totalMoves: moves.count, analyses: analyses)
        let classifier = GamePhaseClassifier(
            totalMoves: moves.count,
            boardSize: boardSize,
            moves: moves,
            analyses: analyses,
            analysisProgress: coverage
        )
        let evaluations = moveEvaluations(targetPlayer: targetPlayer, moves: moves, analyses: analyses, boardSize: boardSize, classifier: classifier)
        let averageLoss = evaluations.map(\.scoreLoss).average
        let blunderCount = evaluations.filter { $0.scoreLoss >= 5.0 || $0.winrateDrop >= 0.12 }.count
        let usedHumanSL = !profileScores.isEmpty
        let sortedProfiles = profileScores.sorted { $0.similarityScore > $1.similarityScore }
        let bestProfile = sortedProfiles.first?.profile
        let keyMistakes = evaluations
            .filter { $0.scoreLoss >= 1.5 || $0.winrateDrop >= 0.04 }
            .sorted {
                if abs($0.scoreLoss - $1.scoreLoss) > 0.3 { return $0.scoreLoss > $1.scoreLoss }
                return $0.winrateDrop > $1.winrateDrop
            }
            .prefix(6)
            .map { $0.keyMistake }

        let mistakes = mistakeBreakdown(from: evaluations)
        let confidence = confidence(
            coverage: coverage,
            evaluatedMoveCount: evaluations.count,
            profileSampleCount: profileScores.map(\.sampleCount).max() ?? 0,
            usedHumanSL: usedHumanSL
        )

        return RankEstimateReport(
            targetPlayer: targetPlayer,
            estimatedRange: estimatedRange(averageLoss: averageLoss, blunderCount: blunderCount, moveCount: max(1, evaluations.count), bestProfile: bestProfile, usedHumanSL: usedHumanSL),
            mostSimilarProfile: bestProfile.map(profileDisplayName),
            confidence: confidence,
            confidenceReason: confidenceReason(confidence: confidence, coverage: coverage, sampleCount: evaluations.count, usedHumanSL: usedHumanSL),
            profileScores: sortedProfiles,
            averageScoreLoss: averageLoss,
            blunderCount: blunderCount,
            phaseBreakdown: phaseBreakdown(from: evaluations),
            mistakeBreakdown: Array(mistakes.prefix(4)),
            keyMistakes: keyMistakes,
            recommendations: recommendations(from: mistakes, phaseBreakdown: phaseBreakdown(from: evaluations)),
            generatedAt: Date(),
            usedHumanSL: usedHumanSL,
            humanSLMessage: humanSLMessage(available: humanSLAvailable, used: usedHumanSL, timedOut: humanSLTimedOut),
            disclaimer: "一盘棋只能做初步估计，不代表正式段位认证。建议完成 3~5 盘测评后再综合判断。"
        )
    }

    private static func moveEvaluations(
        targetPlayer: Stone,
        moves: [Move],
        analyses: [Int: MoveAnalysis],
        boardSize: Int,
        classifier: GamePhaseClassifier
    ) -> [RankMoveEvaluation] {
        guard !moves.isEmpty else { return [] }
        return (1...moves.count).compactMap { turn in
            guard moves.indices.contains(turn - 1),
                  moves[turn - 1].player == targetPlayer,
                  let previous = analyses[turn - 1],
                  let current = analyses[turn] else {
                return nil
            }

            let move = moves[turn - 1]
            let playedMove = move.kind.gtpString(boardSize: boardSize)
            let winrateDrop = max(0, targetPlayer == .black ? previous.winrate - current.winrate : current.winrate - previous.winrate)
            let scoreLoss = max(0, targetPlayer == .black ? previous.scoreLead - current.scoreLead : current.scoreLead - previous.scoreLead)
            let recommendedMove = previous.bestMove?.toGTP(boardSize: boardSize)
            let candidateRank = previous.candidateMoves.first { $0.move.uppercased() == playedMove.uppercased() }?.order
            let phase = classifier.phase(for: turn)
            let mistakeType = classifyMistake(phase: phase, scoreLoss: scoreLoss, winrateDrop: winrateDrop, candidateRank: candidateRank, recommendedMove: recommendedMove)

            return RankMoveEvaluation(
                turn: turn,
                playedMove: playedMove,
                recommendedMove: recommendedMove,
                scoreLoss: scoreLoss,
                winrateDrop: winrateDrop,
                candidateRank: candidateRank,
                phase: phase,
                mistakeType: mistakeType
            )
        }
    }

    private static func classifyMistake(
        phase: GamePhase,
        scoreLoss: Double,
        winrateDrop: Double,
        candidateRank: Int?,
        recommendedMove: String?
    ) -> RankMistakeType {
        guard scoreLoss >= 0.8 || winrateDrop >= 0.025 else { return .unclear }
        if phase == .endgame { return .endgame }
        if phase == .opening {
            if candidateRank == nil || scoreLoss >= 3.0 { return .openingDirection }
            return .bigPointJudgement
        }
        if scoreLoss >= 6.0 || winrateDrop >= 0.12 { return .fightingReading }
        if candidateRank == nil { return .attackDefensePriority }
        if candidateRank.map({ $0 >= 3 }) ?? false { return .bigPointJudgement }
        if recommendedMove != nil, scoreLoss >= 2.5 { return .safety }
        return .unclear
    }

    private static func phaseBreakdown(from evaluations: [RankMoveEvaluation]) -> PhaseBreakdown {
        PhaseBreakdown(
            opening: phaseSummary(title: GamePhase.opening.title, phase: .opening, evaluations: evaluations),
            middleGame: phaseSummary(title: GamePhase.middleGame.title, phase: .middleGame, evaluations: evaluations),
            endgame: phaseSummary(title: GamePhase.endgame.title, phase: .endgame, evaluations: evaluations)
        )
    }

    private static func phaseSummary(title: String, phase: GamePhase, evaluations: [RankMoveEvaluation]) -> RankPhaseSummary {
        let phaseEvaluations = evaluations.filter { $0.phase == phase }
        return RankPhaseSummary(
            title: title,
            moveCount: phaseEvaluations.count,
            averageScoreLoss: phaseEvaluations.map(\.scoreLoss).average,
            totalScoreLoss: phaseEvaluations.map(\.scoreLoss).reduce(0, +),
            majorMistakeCount: phaseEvaluations.filter { $0.scoreLoss >= 3.0 || $0.winrateDrop >= 0.08 }.count
        )
    }

    private static func mistakeBreakdown(from evaluations: [RankMoveEvaluation]) -> [MistakeBreakdown] {
        let meaningful = evaluations.filter { $0.mistakeType != .unclear && ($0.scoreLoss >= 1.0 || $0.winrateDrop >= 0.03) }
        let grouped = Dictionary(grouping: meaningful, by: \.mistakeType)
        return grouped.map { type, items in
            MistakeBreakdown(
                type: type,
                count: items.count,
                totalScoreLoss: items.map(\.scoreLoss).reduce(0, +),
                explanation: explanation(for: type)
            )
        }
        .sorted {
            if $0.count == $1.count { return $0.totalScoreLoss > $1.totalScoreLoss }
            return $0.count > $1.count
        }
    }

    private static func estimatedRange(averageLoss: Double, blunderCount: Int, moveCount: Int, bestProfile: String?, usedHumanSL: Bool) -> String {
        if usedHumanSL, let bestProfile {
            return range(for: bestProfile)
        }

        let blunderRate = Double(blunderCount) / Double(max(1, moveCount))
        if averageLoss >= 5.0 || blunderRate >= 0.22 { return "业余1段 ~ 业余2段" }
        if averageLoss >= 3.2 || blunderRate >= 0.14 { return "业余2段 ~ 业余3段" }
        if averageLoss >= 2.0 || blunderRate >= 0.08 { return "业余3段 ~ 业余5段" }
        if averageLoss >= 1.1 { return "业余5段 ~ 业余8段" }
        return "业余8段 ~ 职业初段"
    }

    private static func range(for profile: String) -> String {
        switch profile {
        case "rank_20k": return "业余1段 ~ 业余2段"
        case "rank_15k": return "业余2段 ~ 业余3段"
        case "rank_10k": return "业余3段 ~ 业余4段"
        case "rank_5k": return "业余4段 ~ 业余5段"
        case "rank_1k": return "业余5段 ~ 业余6段"
        case "rank_1d": return "业余6段 ~ 业余7段"
        case "rank_3d": return "业余7段 ~ 业余8段"
        case "rank_5d": return "业余8段 ~ 职业初段"
        case "rank_9d": return "职业初段 ~ 职业九段"
        default: return "业余2段 ~ 业余3段"
        }
    }

    private static func confidence(
        coverage: Double,
        evaluatedMoveCount: Int,
        profileSampleCount: Int,
        usedHumanSL: Bool
    ) -> RankEstimateConfidence {
        if coverage >= 0.78, evaluatedMoveCount >= 35, usedHumanSL, profileSampleCount >= 4 { return .high }
        if coverage >= 0.5, evaluatedMoveCount >= 16 { return .medium }
        return .low
    }

    private static func confidenceReason(confidence: RankEstimateConfidence, coverage: Double, sampleCount: Int, usedHumanSL: Bool) -> String {
        let coverageText = "\(Int(coverage * 100))%"
        switch confidence {
        case .high:
            return "本局可用分析覆盖约 \(coverageText)，并结合了 HumanSL 棋力档样本。"
        case .medium:
            return usedHumanSL
                ? "本局有一定数量的 KataGo 与 HumanSL 样本，但仍建议多盘验证。"
                : "本局有 \(sampleCount) 手可评估，但未使用 HumanSL，相似度判断较粗。"
        case .low:
            return "可用样本偏少或 HumanSL 不可用，本次只能作为初步参考。"
        }
    }

    private static func recommendations(from mistakes: [MistakeBreakdown], phaseBreakdown: PhaseBreakdown) -> [String] {
        var result: [String] = []
        for mistake in mistakes.prefix(3) {
            switch mistake.type {
            case .openingDirection, .bigPointJudgement:
                result.append("布局阶段每手先比较角、边、大场，避免过早进入小范围低价值交换。")
            case .attackDefensePriority, .safety:
                result.append("中盘先问哪块棋最急，优先处理弱棋安定和攻防转换。")
            case .lifeAndDeath, .fightingReading:
                result.append("每天练 10~15 题死活或手筋，重点训练读气、断点和连接。")
            case .endgame:
                result.append("复盘官子时估算双方后续先手，优先走双先和逆收大官子。")
            case .tooConservative:
                result.append("优势或可战局面中多检查主动手，避免只补不争。")
            case .tooAggressive:
                result.append("进攻前先确认自身棋形厚薄和退路，减少无根据强攻。")
            case .unclear:
                break
            }
        }

        let weakestPhase = [phaseBreakdown.opening, phaseBreakdown.middleGame, phaseBreakdown.endgame]
            .max { $0.averageScoreLoss < $1.averageScoreLoss }
        if let weakestPhase, weakestPhase.averageScoreLoss >= 1.5 {
            result.append("下一盘测评时重点观察\(weakestPhase.title)阶段，记录每次明显亏损前的候选点比较。")
        }

        if result.isEmpty {
            result.append("继续保持复盘习惯，重点比较实战手与前三候选点的目的差异。")
            result.append("每手棋落子前先确认当前最大急所，减少凭感觉脱先。")
        }

        return Array(result.prefix(4))
    }

    private static func explanation(for type: RankMistakeType) -> String {
        switch type {
        case .openingDirection: return "布局阶段方向选择与全局效率有偏差。"
        case .bigPointJudgement: return "对大场价值和候选顺序的判断还不稳定。"
        case .attackDefensePriority: return "攻防转换时容易错过双方最急的弱点。"
        case .safety: return "补棋、连接或安定时机需要加强。"
        case .lifeAndDeath: return "局部死活和手筋判断可能不够准确。"
        case .fightingReading: return "复杂战斗中计算深度或次序有波动。"
        case .endgame: return "收官阶段对大小、先后手的比较不足。"
        case .tooConservative: return "有机会主动争取时选择偏保守。"
        case .tooAggressive: return "局部选择承担了偏高风险。"
        case .unclear: return "当前数据不足以稳定归因。"
        }
    }

    private static func humanSLMessage(available: Bool, used: Bool, timedOut: Bool) -> String {
        if used { return "本次已使用 HumanSL 做人类棋力档相似度参考。" }
        if !available { return "本次未使用 HumanSL，仅基于 KataGo 普通分析估计。放入 HumanSL 模型后可获得更准确的人类段位相似度分析。" }
        if timedOut { return "HumanSL 查询超时或返回不足，本次报告已降级为 KataGo 普通分析估计。" }
        return "HumanSL 样本不足，本次主要基于 KataGo 普通分析估计。"
    }

    private static func analysisCoverage(totalMoves: Int, analyses: [Int: MoveAnalysis]) -> Double {
        guard totalMoves > 0 else { return 0 }
        let analyzedTurns = (0...totalMoves).filter { analyses[$0] != nil }.count
        return min(1.0, Double(analyzedTurns) / Double(totalMoves + 1))
    }
}

private struct RankMoveEvaluation {
    let turn: Int
    let playedMove: String
    let recommendedMove: String?
    let scoreLoss: Double
    let winrateDrop: Double
    let candidateRank: Int?
    let phase: GamePhase
    let mistakeType: RankMistakeType

    var keyMistake: KeyMistake {
        KeyMistake(
            turn: turn,
            playedMove: playedMove,
            recommendedMove: recommendedMove,
            scoreDrop: scoreLoss,
            winrateDrop: winrateDrop,
            mistakeType: mistakeType,
            shortReason: shortReason
        )
    }

    private var shortReason: String {
        if let recommendedMove, playedMove.uppercased() != recommendedMove.uppercased() {
            return "实战手未贴近当前候选主线，可优先比较 \(recommendedMove) 的全局价值。"
        }
        if scoreLoss >= 3.0 {
            return "这手之后目差波动较大，建议复盘当时的候选点排序。"
        }
        return "这手造成了一定损失，适合回看落子目的和先后手。"
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
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

private extension Move {
    var isPassMove: Bool {
        if case .pass = kind { return true }
        return false
    }
}
