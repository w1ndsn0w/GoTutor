//
//  TsumegoListView.swift
//  GoTutor
//
//  Created by 袁守航 on 2026/3/16.
//

import SwiftUI

struct TsumegoListView: View {
    @Environment(\.dismiss) private var dismiss

    // 读取我们刚才写的模拟题库
    let problems = TsumegoBank.beginnerProblems
    var showsCloseButton = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("入门死活题 (共 \(problems.count) 题)")) {
                    ForEach(problems) { problem in
                        NavigationLink(destination: TsumegoSolvingView(problem: problem)) {
                            HStack {
                                // 题号圆圈
                                Text("\(problem.number)")
                                    .font(.headline)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(problem.title)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("难度: \(problem.difficulty) | \(problem.firstToPlay == .black ? "黑先" : "白先")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("死活题训练")
            // 顶部加一个“顺序刷题”的快捷按钮
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if let first = problems.first {
                        NavigationLink(destination: TsumegoSolvingView(problem: first)) {
                            Text("从头开始")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 占位的做题界面 (下一步我们将重点完善这里)
struct TsumegoSolvingView: View {
    let problem: TsumegoProblem
    
    var body: some View {
        VStack(spacing: 20) {
            Text("正在挑战：第 \(problem.number) 题")
                .font(.title2).bold()
            
            Text(problem.title)
                .foregroundColor(.secondary)
            
            // TODO: 这里之后会放你的 GoBoardWithCoordinatesView
            Rectangle()
                .fill(Color(UIColor.systemGroupedBackground))
                .aspectRatio(1, contentMode: .fit)
                .overlay(Text("这里将渲染局部棋盘\n并加载 SGF：\n\(problem.sgfContent.prefix(20))...").multilineTextAlignment(.center))
                .padding()
            
            Spacer()
        }
        .navigationTitle("第 \(problem.number) 题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TsumegoListView()
}
