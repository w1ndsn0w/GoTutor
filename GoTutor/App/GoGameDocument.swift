import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static var smartGameFormat: UTType { UTType(importedAs: "com.red-bean.sgf") }
}

struct GoGameDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.json, .smartGameFormat] }
    static var writableContentTypes: [UTType] { [.smartGameFormat, .json] }
    var savedGame: SavedGame

    init(savedGame: SavedGame) {
        self.savedGame = savedGame
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let preferredExtension = configuration.contentType.preferredFilenameExtension
        self.savedGame = try SavedGame.parse(from: data, preferredFileExtension: preferredExtension)
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = configuration.contentType == .json ? try savedGame.toData() : try savedGame.toSGFData()
        return .init(regularFileWithContents: data)
    }
}
