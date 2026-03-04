import Foundation

// MARK: - Core Game Types

enum Stone: Int, Codable {
    case empty = 0, black = 1, white = 2
    var opponent: Stone { self == .black ? .white : (self == .white ? .black : .empty) }
    var next: Stone { self == .black ? .white : .black }
}

struct Point: Hashable, Codable {
    let r: Int // 行 (0 到 18)
    let c: Int // 列 (0 到 18)
    
    // GTP 协议的双向翻译助手
    func toGTP() -> String {
        let letters = Array("ABCDEFGHJKLMNOPQRST")
        guard c >= 0 && c < 19 && r >= 0 && r < 19 else { return "pass" }
        return "\(String(letters[c]))\(19 - r)"
    }
    
    init?(gtp: String) {
        let upperStr = gtp.uppercased()
        guard upperStr.count >= 2, upperStr != "PASS" else { return nil }
        let letter = upperStr.first!
        let numberStr = upperStr.dropFirst()
        let letters = Array("ABCDEFGHJKLMNOPQRST")
        guard let cIndex = letters.firstIndex(of: letter),
              let number = Int(numberStr) else { return nil }
        self.c = cIndex
        self.r = 19 - number
    }
    
    init(r: Int, c: Int) {
        self.r = r
        self.c = c
    }
}

enum MoveKind: Codable, Equatable {
    case place(Point)
    case pass
}

struct Move: Codable, Equatable {
    let player: Stone
    let kind: MoveKind
    let captured: [Point]
}

enum IllegalReason: String, Codable, Equatable {
    case outOfBounds = "超出棋盘范围"
    case occupied = "该位置已有棋子"
    case suicide = "禁入点（自杀）"
    case ko = "打劫（重复盘面）"
}

struct GameSnapshot: Codable, Equatable {
    var board: [[Stone]]
    var currentPlayer: Stone
    var capturesBlack: Int
    var capturesWhite: Int
    var consecutivePasses: Int
    var isGameOver: Bool
    var lastMove: Move?
    var lastIllegalReason: IllegalReason?
    var positionHistory: Set<String>
    var moves: [Move]
}

struct TerritoryAnalysis: Equatable {
    let blackTerritory: Set<Point>
    let whiteTerritory: Set<Point>
    let neutral: Set<Point>
    let deadBlackStones: Int
    let deadWhiteStones: Int
}

// MARK: - Save & Analysis Types

struct MoveAnalysis: Codable, Equatable {
    let winrate: Double
    let scoreLead: Double
    let ownership: [Double]?
    var bestMove: Point? = nil
    var candidateMoves: [CandidateMove] = []
}

struct SavedGame: Codable {
    let size: Int
    let date: Date
    let moves: [Move]
    let analyses: [Int: MoveAnalysis]
}

struct KataGoResponse: Codable {
    let id: String?
    let turnNumber: Int?
    let ownership: [Double]?
    let rootInfo: RootInfo?
    let moveInfos: [MoveInfo]?
    
    struct RootInfo: Codable {
        let winrate: Double?
        let scoreLead: Double?
    }
    
    struct MoveInfo: Codable {
        let move: String
        let winrate: Double?
        let scoreLead: Double?
        let pv: [String]?
    }
}
    struct CandidateMove: Codable, Equatable, Sendable {
        let move: String
        let winrate: Double
        let scoreLead: Double
        let pv: [String]
        let order: Int
    }
