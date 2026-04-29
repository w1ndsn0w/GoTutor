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
    let title: String?
    let blackPlayerName: String?
    let whitePlayerName: String?
    let moves: [Move]
    let analyses: [Int: MoveAnalysis]
}

// 手动实现 Codable 并显式标记为 nonisolated，打破编译器的隔离推断
extension SavedGame: Codable {
    enum CodingKeys: String, CodingKey {
        case size, date, title, blackPlayerName, whitePlayerName, moves, analyses
    }
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.size = try container.decode(Int.self, forKey: .size)
        self.date = try container.decode(Date.self, forKey: .date)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.blackPlayerName = try container.decodeIfPresent(String.self, forKey: .blackPlayerName)
        self.whitePlayerName = try container.decodeIfPresent(String.self, forKey: .whitePlayerName)
        self.moves = try container.decode([Move].self, forKey: .moves)
        self.analyses = try container.decode([Int: MoveAnalysis].self, forKey: .analyses)
    }
    
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.size, forKey: .size)
        try container.encode(self.date, forKey: .date)
        try container.encodeIfPresent(self.title, forKey: .title)
        try container.encodeIfPresent(self.blackPlayerName, forKey: .blackPlayerName)
        try container.encodeIfPresent(self.whitePlayerName, forKey: .whitePlayerName)
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
    enum RecordError: LocalizedError {
        case invalidBoardSize(Int)
        case invalidMoveCoordinate(turn: Int, point: Point)
        case invalidSGFMove(turn: Int, value: String)

        var errorDescription: String? {
            switch self {
            case .invalidBoardSize(let size):
                return "不支持的棋盘路数：\(size)"
            case .invalidMoveCoordinate(let turn, let point):
                return "第 \(turn) 手坐标越界：(\(point.r), \(point.c))"
            case .invalidSGFMove(let turn, let value):
                return "第 \(turn) 手 SGF 坐标无效：\(value)"
            }
        }
    }

    // 明确告诉编译器，解码动作不需要主线程
    nonisolated static func parse(from data: Data) throws -> SavedGame {
        return try JSONDecoder().decode(SavedGame.self, from: data).validated()
    }

    nonisolated static func parse(from data: Data, preferredFileExtension: String?) throws -> SavedGame {
        let fileExtension = preferredFileExtension?.lowercased()
        if fileExtension == "sgf" {
            guard let sgf = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return try SavedGame(sgf: sgf).validated()
        }

        if let content = String(data: data, encoding: .utf8),
           content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("(") {
            return try SavedGame(sgf: content).validated()
        }

        return try parse(from: data)
    }
    
    // 明确告诉编译器，编码动作不需要主线程
    nonisolated func toData() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    nonisolated func toSGFData() throws -> Data {
        guard let data = toSGFString().data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return data
    }

    nonisolated func toSGFString() -> String {
        var sgf = "(;GM[1]FF[4]CA[UTF-8]AP[GoTutor]SZ[\(size)]DT[\(Self.sgfDateString(from: date))]KM[7.5]"
        if let title = Self.normalizedText(title) {
            sgf += "GN[\(Self.escapedSGFValue(title))]"
        }
        if let blackPlayerName = Self.normalizedText(blackPlayerName) {
            sgf += "PB[\(Self.escapedSGFValue(blackPlayerName))]"
        }
        if let whitePlayerName = Self.normalizedText(whitePlayerName) {
            sgf += "PW[\(Self.escapedSGFValue(whitePlayerName))]"
        }
        for move in moves {
            let player = move.player == .black ? "B" : "W"
            switch move.kind {
            case .place(let point):
                sgf += ";\(player)[\(point.toSGF(boardSize: size))]"
            case .pass:
                sgf += ";\(player)[]"
            }
        }
        sgf += ")"
        return sgf
    }

    nonisolated init(sgf: String) throws {
        let tree = try SGFParser.parse(string: sgf)
        let root = tree.rootNode
        let boardSize = Self.parseSGFBoardSize(root.properties["SZ"]?.first)
        let date = Self.parseSGFDate(root.properties["DT"]?.first) ?? Date()
        let title = root.properties["GN"]?.first
        let blackPlayerName = root.properties["PB"]?.first
        let whitePlayerName = root.properties["PW"]?.first

        var parsedMoves: [Move] = []
        var node: SGFNode? = root
        while let current = node {
            if let blackMove = current.properties["B"]?.first {
                parsedMoves.append(try Self.move(player: .black, sgfValue: blackMove, turn: parsedMoves.count + 1, boardSize: boardSize))
            } else if let whiteMove = current.properties["W"]?.first {
                parsedMoves.append(try Self.move(player: .white, sgfValue: whiteMove, turn: parsedMoves.count + 1, boardSize: boardSize))
            }
            node = current.children.first
        }

        self.init(
            size: boardSize,
            date: date,
            title: title,
            blackPlayerName: blackPlayerName,
            whitePlayerName: whitePlayerName,
            moves: parsedMoves,
            analyses: [:]
        )
    }

    nonisolated func validated() throws -> SavedGame {
        guard (2...19).contains(size) else { throw RecordError.invalidBoardSize(size) }

        for (index, move) in moves.enumerated() {
            switch move.kind {
            case .place(let point):
                guard point.isOnBoard(size: size) else {
                    throw RecordError.invalidMoveCoordinate(turn: index + 1, point: point)
                }
            case .pass:
                break
            }

            for point in move.captured {
                guard point.isOnBoard(size: size) else {
                    throw RecordError.invalidMoveCoordinate(turn: index + 1, point: point)
                }
            }
        }

        let filteredAnalyses = analyses.reduce(into: [Int: MoveAnalysis]()) { result, item in
            let (turn, analysis) = item
            guard turn >= 0 && turn <= moves.count else { return }
            let ownership = analysis.ownership?.count == size * size ? analysis.ownership : nil
            result[turn] = MoveAnalysis(
                winrate: analysis.winrate,
                scoreLead: analysis.scoreLead,
                ownership: ownership,
                bestMove: analysis.bestMove?.isOnBoard(size: size) == true ? analysis.bestMove : nil,
                candidateMoves: analysis.candidateMoves
            )
        }

        return SavedGame(
            size: size,
            date: date,
            title: Self.normalizedText(title),
            blackPlayerName: Self.normalizedText(blackPlayerName),
            whitePlayerName: Self.normalizedText(whitePlayerName),
            moves: moves,
            analyses: filteredAnalyses
        )
    }

    private nonisolated static func move(player: Stone, sgfValue: String, turn: Int, boardSize: Int) throws -> Move {
        let value = sgfValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.lowercased() == "tt" {
            return Move(player: player, kind: .pass, captured: [])
        }
        guard let point = Point(sgf: value, boardSize: boardSize) else {
            throw RecordError.invalidSGFMove(turn: turn, value: sgfValue)
        }
        return Move(player: player, kind: .place(point), captured: [])
    }

    private nonisolated static func sgfDateString(from date: Date) -> String {
        sgfDateFormatter().string(from: date)
    }

    private nonisolated static func parseSGFDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let firstDate = value.split(separator: ",").first.map(String.init) ?? value
        return sgfDateFormatter().date(from: firstDate)
    }

    private nonisolated static func parseSGFBoardSize(_ value: String?) -> Int {
        guard let value else { return 19 }
        let firstDimension = value.split(separator: ":").first.map(String.init) ?? value
        return Int(firstDimension.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 19
    }

    private nonisolated static func sgfDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private nonisolated static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func escapedSGFValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}
// MARK: - SGF 坐标转换

extension Point {
    // 1. 从 SGF 坐标串初始化 (例如 "pd" -> r: 3, c: 15)
    nonisolated init?(sgf: String, boardSize: Int = 19) {
        guard sgf.count == 2 else { return nil }
        let chars = Array(sgf.lowercased())
        let cChar = chars[0].asciiValue ?? 0
        let rChar = chars[1].asciiValue ?? 0
        
        // 'a' 的 ASCII 值是 97
        let aValue = Character("a").asciiValue ?? 97
        
        self.c = Int(cChar - aValue)
        self.r = Int(rChar - aValue)
        
        // 简单越界保护 (允许 pass 等特殊情况，但只解析盘内坐标)
        guard isOnBoard(size: boardSize) else { return nil }
    }
    
    // 2. 导出为 SGF 格式坐标 (方便以后保存用户的修改)
    nonisolated func toSGF(boardSize: Int = 19) -> String {
        guard isOnBoard(size: boardSize) else { return "" }
        let aValue = Int(Character("a").asciiValue ?? 97)
        let cStr = String(UnicodeScalar(aValue + self.c)!)
        let rStr = String(UnicodeScalar(aValue + self.r)!)
        return "\(cStr)\(rStr)"
    }

    nonisolated func isOnBoard(size: Int) -> Bool {
        r >= 0 && r < size && c >= 0 && c < size
    }
}
