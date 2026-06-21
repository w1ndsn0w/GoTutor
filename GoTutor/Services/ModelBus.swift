import Foundation

enum AnalysisModelSource: String, Codable, Sendable {
    case kataGo
    case humanSL
}

enum AnalysisTaskKind: String, Codable, Sendable {
    case primaryAnalysis
    case coachHint
    case reviewBatch
    case humanSLDebug
    case rankBaseline
    case rankHumanSLMatch
}

enum AnalysisResponseKind: Sendable, Equatable {
    case primaryQuery(turn: Int?)
    case coachHint(turn: Int?)
    case reviewBatch
    case humanSLDebug(profile: String)
    case rankBaseline
    case rankHumanSLMatch(turn: Int, profile: String)
}

struct AnalysisQueryContext: Sendable, Equatable {
    let gameId: String
    let boardSize: Int
    let gtpMoves: [[String]]
    let currentTurn: Int
}

struct AnalysisTaskDescriptor: Sendable, Equatable {
    let kind: AnalysisTaskKind
    let source: AnalysisModelSource
    let rules: String
    let komi: Double?
    let maxVisits: Int
    let includeOwnership: Bool
    let includePolicy: Bool
    let analyzeTurns: [Int]?
    let humanSLProfile: String?
    let targetTurn: Int?

    static func primaryAnalysis(maxVisits: Int, includeOwnership: Bool) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .primaryAnalysis,
            source: .kataGo,
            rules: "chinese",
            komi: nil,
            maxVisits: maxVisits,
            includeOwnership: includeOwnership,
            includePolicy: false,
            analyzeTurns: nil,
            humanSLProfile: nil,
            targetTurn: nil
        )
    }

    static func coachHint(maxVisits: Int, includeOwnership: Bool) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .coachHint,
            source: .kataGo,
            rules: "chinese",
            komi: nil,
            maxVisits: maxVisits,
            includeOwnership: includeOwnership,
            includePolicy: false,
            analyzeTurns: nil,
            humanSLProfile: nil,
            targetTurn: nil
        )
    }

    static func reviewBatch(analyzeTurns: [Int], maxVisits: Int) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .reviewBatch,
            source: .kataGo,
            rules: "chinese",
            komi: nil,
            maxVisits: maxVisits,
            includeOwnership: true,
            includePolicy: true,
            analyzeTurns: analyzeTurns,
            humanSLProfile: nil,
            targetTurn: nil
        )
    }

    static func humanSLDebug(profile: String, maxVisits: Int) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .humanSLDebug,
            source: .humanSL,
            rules: "japanese",
            komi: 6.5,
            maxVisits: maxVisits,
            includeOwnership: false,
            includePolicy: true,
            analyzeTurns: nil,
            humanSLProfile: profile,
            targetTurn: nil
        )
    }

    static func rankBaseline(analyzeTurns: [Int], maxVisits: Int) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .rankBaseline,
            source: .kataGo,
            rules: "chinese",
            komi: nil,
            maxVisits: maxVisits,
            includeOwnership: false,
            includePolicy: false,
            analyzeTurns: analyzeTurns,
            humanSLProfile: nil,
            targetTurn: nil
        )
    }

    static func rankHumanSLMatch(profile: String, targetTurn: Int, maxVisits: Int) -> AnalysisTaskDescriptor {
        AnalysisTaskDescriptor(
            kind: .rankHumanSLMatch,
            source: .humanSL,
            rules: "japanese",
            komi: 6.5,
            maxVisits: maxVisits,
            includeOwnership: false,
            includePolicy: true,
            analyzeTurns: nil,
            humanSLProfile: profile,
            targetTurn: targetTurn
        )
    }
}

struct AnalysisRequest: Sendable, Equatable {
    let id: String
    let descriptor: AnalysisTaskDescriptor
    let context: AnalysisQueryContext
}

struct AnalysisResponseRoute: Sendable, Equatable {
    let gameId: String
    let kind: AnalysisResponseKind

    init?(responseId: String, gameId: String) {
        guard responseId.hasPrefix(gameId) else { return nil }
        let suffixStart = responseId.index(responseId.startIndex, offsetBy: gameId.count)
        guard suffixStart < responseId.endIndex, responseId[suffixStart] == "_" else { return nil }

        let suffix = String(responseId[responseId.index(after: suffixStart)...])
        if suffix == "batch_review" {
            self.gameId = gameId
            self.kind = .reviewBatch
            return
        }
        if suffix == "rank_baseline" {
            self.gameId = gameId
            self.kind = .rankBaseline
            return
        }
        if suffix.hasPrefix("rank_humansl_") {
            let payload = String(suffix.dropFirst("rank_humansl_".count))
            let parts = payload.split(separator: "_", maxSplits: 1).map(String.init)
            if parts.count == 2, let turn = Int(parts[0]) {
                self.gameId = gameId
                self.kind = .rankHumanSLMatch(turn: turn, profile: parts[1])
                return
            }
        }
        if suffix.hasPrefix("human_test_") {
            self.gameId = gameId
            self.kind = .humanSLDebug(profile: String(suffix.dropFirst("human_test_".count)))
            return
        }
        if suffix.hasPrefix("human_hint_") {
            self.gameId = gameId
            self.kind = .coachHint(turn: Int(suffix.dropFirst("human_hint_".count)))
            return
        }
        if suffix.hasPrefix("query_") {
            self.gameId = gameId
            self.kind = .primaryQuery(turn: Int(suffix.dropFirst("query_".count)))
            return
        }

        return nil
    }
}

struct HumanSLAnalysisResult: Sendable, Equatable {
    let profile: String
    let policy: [Double]?
    let candidateMoves: [CandidateMove]
}

@MainActor
final class KataGoModelBus {
    static let shared = KataGoModelBus()

    private let engine = KataGoWrapper.shared()

    private init() {}

    func startEngine(modelPath: String, configPath: String, humanModelPath: String?) -> String {
        engine.setEngineWithModel(modelPath, config: configPath, humanModel: humanModelPath)
    }

    @discardableResult
    func send(_ descriptor: AnalysisTaskDescriptor, context: AnalysisQueryContext) -> AnalysisRequest? {
        let request = AnalysisRequest(
            id: Self.makeRequestID(for: descriptor, context: context),
            descriptor: descriptor,
            context: context
        )
        guard let jsonString = Self.makeJSONString(for: request) else { return nil }
        engine.sendQuery(jsonString)
        return request
    }

    private static func makeRequestID(for descriptor: AnalysisTaskDescriptor, context: AnalysisQueryContext) -> String {
        switch descriptor.kind {
        case .primaryAnalysis:
            return "\(context.gameId)_query_\(context.currentTurn)"
        case .coachHint:
            return "\(context.gameId)_human_hint_\(context.currentTurn)"
        case .reviewBatch:
            return "\(context.gameId)_batch_review"
        case .humanSLDebug:
            let profile = descriptor.humanSLProfile ?? "unknown"
            return "\(context.gameId)_human_test_\(profile)"
        case .rankBaseline:
            return "\(context.gameId)_rank_baseline"
        case .rankHumanSLMatch:
            let profile = descriptor.humanSLProfile ?? "unknown"
            let turn = descriptor.targetTurn ?? context.currentTurn
            return "\(context.gameId)_rank_humansl_\(turn)_\(profile)"
        }
    }

    private static func makeJSONString(for request: AnalysisRequest) -> String? {
        let descriptor = request.descriptor
        let context = request.context
        let analyzeTurns = descriptor.analyzeTurns ?? [context.gtpMoves.count]

        var queryDict: [String: Any] = [
            "id": request.id,
            "moves": context.gtpMoves,
            "rules": descriptor.rules,
            "boardXSize": context.boardSize,
            "boardYSize": context.boardSize,
            "maxVisits": descriptor.maxVisits
        ]

        if descriptor.kind != .humanSLDebug && descriptor.kind != .rankHumanSLMatch {
            queryDict["analyzeTurns"] = analyzeTurns
        }
        if descriptor.includeOwnership {
            queryDict["includeOwnership"] = true
        }
        if descriptor.includePolicy {
            queryDict["includePolicy"] = true
        }
        if let komi = descriptor.komi {
            queryDict["komi"] = komi
        }
        if let humanSLProfile = descriptor.humanSLProfile {
            queryDict["overrideSettings"] = [
                "humanSLProfile": humanSLProfile
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: queryDict) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    static func humanMoveSimilarity(from response: KataGoResponse, playedMove: String, boardSize: Int) -> Double? {
        let normalizedMove = playedMove.uppercased()
        if let moveInfo = response.moveInfos?.first(where: { $0.move.uppercased() == normalizedMove }),
           let humanPrior = moveInfo.humanPrior ?? moveInfo.prior {
            return humanPrior
        }

        if normalizedMove == "PASS" {
            return response.humanPolicy?.last ?? response.policy?.last
        }

        guard let point = Point(gtp: normalizedMove, boardSize: boardSize) else { return nil }
        let index = point.r * boardSize + point.c
        if let humanPolicy = response.humanPolicy, humanPolicy.indices.contains(index) {
            return humanPolicy[index]
        }
        if let policy = response.policy, policy.indices.contains(index) {
            return policy[index]
        }
        return nil
    }
}

enum KataGoResponseMapper {
    static func moveAnalysis(from response: KataGoResponse, boardSize: Int) -> MoveAnalysis? {
        guard let info = response.rootInfo,
              let winrate = info.winrate,
              let scoreLead = info.scoreLead else {
            return nil
        }

        var bestMove: Point?
        var candidateMoves: [CandidateMove] = []

        if let moveInfos = response.moveInfos {
            if let bestMoveString = moveInfos.first?.move {
                bestMove = Point(gtp: bestMoveString, boardSize: boardSize)
            }

            for (index, moveInfo) in moveInfos.prefix(3).enumerated() {
                candidateMoves.append(CandidateMove(
                    move: moveInfo.move,
                    winrate: moveInfo.winrate ?? winrate,
                    scoreLead: moveInfo.scoreLead ?? scoreLead,
                    pv: moveInfo.pv ?? [],
                    order: moveInfo.order ?? index + 1,
                    prior: moveInfo.prior,
                    humanPrior: moveInfo.humanPrior,
                    visits: moveInfo.visits ?? moveInfo.edgeVisits
                ))
            }
        }

        return MoveAnalysis(
            winrate: winrate,
            scoreLead: scoreLead,
            ownership: response.ownership,
            bestMove: bestMove,
            candidateMoves: candidateMoves
        )
    }

    static func humanSLAnalysis(from response: KataGoResponse, profile: String) -> HumanSLAnalysisResult {
        let fallbackWinrate = response.rootInfo?.winrate ?? 0
        let fallbackScoreLead = response.rootInfo?.scoreLead ?? 0
        let candidateMoves = response.moveInfos?.prefix(3).enumerated().map { index, moveInfo in
            CandidateMove(
                move: moveInfo.move,
                winrate: moveInfo.winrate ?? fallbackWinrate,
                scoreLead: moveInfo.scoreLead ?? fallbackScoreLead,
                pv: moveInfo.pv ?? [],
                order: moveInfo.order ?? index + 1,
                prior: moveInfo.prior,
                humanPrior: moveInfo.humanPrior,
                visits: moveInfo.visits ?? moveInfo.edgeVisits
            )
        } ?? []

        return HumanSLAnalysisResult(
            profile: profile,
            policy: response.humanPolicy ?? response.policy,
            candidateMoves: candidateMoves
        )
    }
}
