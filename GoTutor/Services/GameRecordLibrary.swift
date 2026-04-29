import Foundation

struct GameRecord: Identifiable {
    let id: URL
    let url: URL
    let savedGame: SavedGame
    let modifiedAt: Date

    var title: String {
        savedGame.displayTitle(fallbackFilename: url.deletingPathExtension().lastPathComponent)
    }

    var playersText: String {
        let black = savedGame.blackPlayerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let white = savedGame.whitePlayerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let blackName = black?.isEmpty == false ? black! : "黑棋"
        let whiteName = white?.isEmpty == false ? white! : "白棋"
        return "\(blackName) vs \(whiteName)"
    }

    var analysisStatusText: String {
        if savedGame.moves.isEmpty { return "空棋谱" }
        if savedGame.hasCompleteAIAnalysis { return "AI 已分析" }
        if savedGame.analyzedTurnCount > 0 {
            return "AI 待补全 \(savedGame.analyzedTurnCount)/\(savedGame.totalAnalysisTurnCount)"
        }
        return "待 AI 分析"
    }

    var analysisStatusIcon: String {
        savedGame.hasCompleteAIAnalysis ? "checkmark.seal.fill" : "sparkles"
    }
}

enum GameRecordLibrary {
    private static let folderName = "GameRecords"

    static var recordsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(folderName, isDirectory: true)
    }

    static func records() throws -> [GameRecord] {
        try ensureDirectoryExists()
        let urls = try FileManager.default.contentsOfDirectory(
            at: recordsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url in
                do {
                    let data = try Data(contentsOf: url)
                    let savedGame = try SavedGame.parse(from: data, preferredFileExtension: url.pathExtension)
                    let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                    return GameRecord(
                        id: url,
                        url: url,
                        savedGame: savedGame,
                        modifiedAt: values.contentModificationDate ?? savedGame.date
                    )
                } catch {
                    return nil
                }
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    @discardableResult
    static func save(_ savedGame: SavedGame) throws -> URL {
        try ensureDirectoryExists()
        let filename = uniqueFilename(for: savedGame)
        let url = recordsDirectory.appendingPathComponent(filename)
        let data = try savedGame.toData()
        try data.write(to: url, options: [.atomic])
        return url
    }

    static func delete(_ record: GameRecord) throws {
        try FileManager.default.removeItem(at: record.url)
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
    }

    private static func uniqueFilename(for savedGame: SavedGame) -> String {
        let base = sanitizedFilename(savedGame.displayTitle(fallbackFilename: defaultTitle(for: savedGame)))
        var candidate = "\(base).json"
        var index = 2

        while FileManager.default.fileExists(atPath: recordsDirectory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(index).json"
            index += 1
        }

        return candidate
    }

    private static func defaultTitle(for savedGame: SavedGame) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "GoTutor-\(savedGame.size)路-\(formatter.string(from: savedGame.date))"
    }

    private static func sanitizedFilename(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:").union(.newlines)
        let parts = value.components(separatedBy: invalidCharacters)
        let cleaned = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "GoTutor-棋谱" : String(cleaned.prefix(80))
    }
}

extension SavedGame {
    nonisolated var totalAnalysisTurnCount: Int {
        moves.isEmpty ? 0 : moves.count + 1
    }

    nonisolated var analyzedTurnCount: Int {
        guard !moves.isEmpty else { return 0 }
        return (0...moves.count).filter { hasUsableAIAnalysis(for: $0) }.count
    }

    nonisolated var hasCompleteAIAnalysis: Bool {
        guard !moves.isEmpty else { return false }
        return analyzedTurnCount == totalAnalysisTurnCount
    }

    nonisolated func missingAnalysisTurns() -> [Int] {
        guard !moves.isEmpty else { return [] }
        return (0...moves.count).filter { !hasUsableAIAnalysis(for: $0) }
    }

    nonisolated func displayTitle(fallbackFilename: String) -> String {
        if let title = normalizedDisplayText(title) {
            return title
        }

        let black = normalizedDisplayText(blackPlayerName)
        let white = normalizedDisplayText(whitePlayerName)
        if let black, let white {
            return "\(black) vs \(white)"
        }

        if let black {
            return "\(black) 执黑"
        }

        if let white {
            return "\(white) 执白"
        }

        return fallbackFilename
    }

    private nonisolated func hasUsableAIAnalysis(for turn: Int) -> Bool {
        guard let analysis = analyses[turn] else { return false }
        return analysis.ownership?.count == size * size
    }

    private nonisolated func normalizedDisplayText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
