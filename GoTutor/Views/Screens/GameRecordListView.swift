import SwiftUI

struct GameRecordListView: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenRecord: (GameRecord) -> Void

    @State private var records: [GameRecord] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "还没有保存的棋谱",
                        systemImage: "tray",
                        description: Text("保存对局后，会在这里集中显示。")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            Button {
                                onOpenRecord(record)
                                dismiss()
                            } label: {
                                GameRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("已保存棋谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("棋谱库", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("确定", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                loadRecords()
            }
        }
    }

    private func loadRecords() {
        do {
            records = try GameRecordLibrary.records()
            errorMessage = nil
        } catch {
            errorMessage = "读取棋谱库失败：\(error.localizedDescription)"
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        do {
            for index in offsets {
                try GameRecordLibrary.delete(records[index])
            }
            records.remove(atOffsets: offsets)
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            loadRecords()
        }
    }
}

private struct GameRecordRow: View {
    let record: GameRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "checkerboard.rectangle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(record.playersText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("\(record.savedGame.size)路", systemImage: "square.grid.3x3")
                    Label("\(record.savedGame.moves.count)手", systemImage: "number")
                    Label(record.analysisStatusText, systemImage: record.analysisStatusIcon)
                        .foregroundStyle(record.savedGame.hasCompleteAIAnalysis ? .green : .secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}
