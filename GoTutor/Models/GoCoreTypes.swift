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
    
    private static let gtpLetters = Array("ABCDEFGHJKLMNOPQRST")

    // GTP 协议的双向翻译助手
    func toGTP(boardSize: Int = 19) -> String {
        guard c >= 0 && c < boardSize && c < Self.gtpLetters.count && r >= 0 && r < boardSize else { return "pass" }
        return "\(String(Self.gtpLetters[c]))\(boardSize - r)"
    }
    
    init?(gtp: String, boardSize: Int = 19) {
        let upperStr = gtp.uppercased()
        guard upperStr.count >= 2, upperStr != "PASS" else { return nil }
        let letter = upperStr.first!
        let numberStr = upperStr.dropFirst()
        guard let cIndex = Self.gtpLetters.firstIndex(of: letter),
              let number = Int(numberStr),
              cIndex < boardSize,
              number >= 1,
              number <= boardSize else { return nil }
        self.c = cIndex
        self.r = boardSize - number
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

struct GameSnapshot: Codable, Equatable, Sendable {
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

struct TerritoryAnalysis: Equatable, Sendable {
    let blackTerritory: Set<Point>
    let whiteTerritory: Set<Point>
    let neutral: Set<Point>
    let deadBlackStones: Int
    let deadWhiteStones: Int
}

// MARK: - Save & Analysis Types

struct MoveAnalysis: Codable, Equatable, Sendable {
    let winrate: Double
    let scoreLead: Double
    let ownership: [Double]?
    var bestMove: Point? = nil
    var candidateMoves: [CandidateMove] = []
}

struct SavedGame: Sendable {
    let size: Int
    let date: Date
    let moves: [Move]
    let analyses: [Int: MoveAnalysis]
}

// 手动实现 Codable 并显式标记为 nonisolated，打破编译器的隔离推断
extension SavedGame: Codable {
    enum CodingKeys: String, CodingKey {
        case size, date, moves, analyses
    }
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.size = try container.decode(Int.self, forKey: .size)
        self.date = try container.decode(Date.self, forKey: .date)
        self.moves = try container.decode([Move].self, forKey: .moves)
        self.analyses = try container.decode([Int: MoveAnalysis].self, forKey: .analyses)
    }
    
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.size, forKey: .size)
        try container.encode(self.date, forKey: .date)
        try container.encode(self.moves, forKey: .moves)
        try container.encode(self.analyses, forKey: .analyses)
    }
}

struct KataGoResponse: Codable, Sendable {
    let id: String?
    let turnNumber: Int?
    let ownership: [Double]?
    let rootInfo: RootInfo?
    let moveInfos: [MoveInfo]?
    
    struct RootInfo: Codable, Sendable {
        let winrate: Double?
        let scoreLead: Double?
    }
    
    struct MoveInfo: Codable, Sendable {
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

extension SavedGame {
    // 明确告诉编译器，解码动作不需要主线程
    nonisolated static func parse(from data: Data) throws -> SavedGame {
        return try JSONDecoder().decode(SavedGame.self, from: data)
    }
    
    // 明确告诉编译器，编码动作不需要主线程
    nonisolated func toData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
}
// MARK: - SGF 坐标转换

extension Point {
    // 1. 从 SGF 坐标串初始化 (例如 "pd" -> r: 3, c: 15)
    init?(sgf: String) {
        guard sgf.count == 2 else { return nil }
        let chars = Array(sgf.lowercased())
        let cChar = chars[0].asciiValue ?? 0
        let rChar = chars[1].asciiValue ?? 0
        
        // 'a' 的 ASCII 值是 97
        let aValue = Character("a").asciiValue ?? 97
        
        self.c = Int(cChar - aValue)
        self.r = Int(rChar - aValue)
        
        // 简单越界保护 (允许 pass 等特殊情况，但只解析盘内坐标)
        guard c >= 0 && c < 19 && r >= 0 && r < 19 else { return nil }
    }
    
    // 2. 导出为 SGF 格式坐标 (方便以后保存用户的修改)
    func toSGF() -> String {
        let aValue = Int(Character("a").asciiValue ?? 97)
        let cStr = String(UnicodeScalar(aValue + self.c)!)
        let rStr = String(UnicodeScalar(aValue + self.r)!)
        return "\(cStr)\(rStr)"
    }
}
