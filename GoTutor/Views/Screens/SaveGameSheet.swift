import SwiftUI

struct SaveGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var blackPlayerName: String
    @Binding var whitePlayerName: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("棋谱命名") {
                    TextField("棋谱标题", text: $title)
                        .textInputAutocapitalization(.never)
                }

                Section("对局双方") {
                    TextField("黑棋", text: $blackPlayerName)
                        .textInputAutocapitalization(.never)
                    TextField("白棋", text: $whitePlayerName)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("保存棋谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
