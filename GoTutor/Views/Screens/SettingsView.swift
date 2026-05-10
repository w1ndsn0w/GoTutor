import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("showCoordinates") private var showCoordinates: Bool = true
    @AppStorage("showStarPoints") private var showStarPoints: Bool = true
    @AppStorage("showHoverGhost") private var showHoverGhost: Bool = true
    @AppStorage("showLastMoveMark") private var showLastMoveMark: Bool = true
    @AppStorage("useWoodBackground") private var useWoodBackground: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("棋盘显示") {
                    Toggle(isOn: $showCoordinates) {
                        Label("显示坐标", systemImage: "number")
                    }

                    Toggle(isOn: $showStarPoints) {
                        Label("显示星位", systemImage: "sparkle")
                    }

                    Toggle(isOn: $showLastMoveMark) {
                        Label("显示落子高亮", systemImage: "smallcircle.filled.circle")
                    }

                    Toggle(isOn: $showHoverGhost) {
                        Label("显示悬停落子点", systemImage: "pencil.tip")
                    }
                }
                
                Section("外观与材质") {
                    Toggle(isOn: $useWoodBackground) {
                        Label("实木纹理棋盘", systemImage: "square.split.diagonal")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}
