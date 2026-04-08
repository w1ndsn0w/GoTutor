import SwiftUI
import UniformTypeIdentifiers

struct GoGameDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.json] }
    var savedGame: SavedGame

    init(savedGame: SavedGame) {
        self.savedGame = savedGame
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.savedGame = try SavedGame.parse(from: data)
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try savedGame.toData()
        return .init(regularFileWithContents: data)
    }
}
