import SwiftUI

struct SettingsView: View {
    // iPad 专属：用来关闭当前弹窗的环境变量
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("showCoordinates") private var showCoordinates: Bool = true
    @AppStorage("showStarPoints") private var showStarPoints: Bool = true
    @AppStorage("showHoverGhost") private var showHoverGhost: Bool = true
    @AppStorage("showLastMoveMark") private var showLastMoveMark: Bool = true
    @AppStorage("useWoodBackground") private var useWoodBackground: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("棋盘显示")) {
                    Toggle("显示坐标", isOn: $showCoordinates)
                    Toggle("显示星位", isOn: $showStarPoints)
                    Toggle("显示落子高亮", isOn: $showLastMoveMark)
                    Toggle("显示悬停落子点 (需 Apple Pencil)", isOn: $showHoverGhost)
                }
                
                Section(header: Text("外观与材质")) {
                    Toggle("使用实木纹理背景", isOn: $useWoodBackground)
                }
            }
            .navigationTitle("偏好设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.body.bold())
                }
            }
        }
        // 在 iPad 上，Form 会自动呈现出非常漂亮的分组卡片样式
    }
}
