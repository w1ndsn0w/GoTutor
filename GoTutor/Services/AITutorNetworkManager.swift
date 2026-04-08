//
//  AITutorNetworkManager.swift
//  Go
//
//  Created by 袁守航 on 2026/3/2.
//

import Foundation

struct TeachingInput: Sendable {
    let turn: Int
    let toPlay: String
    let playedMove: String
    let mistakeType: String
    let severity: String
    let wrDrop: Double
    let scoreDrop: Double
    let playedRank: Int?
    let bestCandidate: CandidateMove
    let keyPV: [String]
}

final class AITutorNetworkManager: Sendable {
    static let shared = AITutorNetworkManager()
    
    private var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["DeepSeekAPIKey"] as? String, !key.isEmpty else {
            print("❌ 严重错误: 找不到 DeepSeek API Key！请检查 Secrets.xcconfig 和 Info.plist 配置。")
            return ""
        }
        return key
    }
    private let endpoint = "https://api.deepseek.com/chat/completions"
    private let model = "deepseek-chat"

    func fetchExplanationStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        streamChatCompletion(
            systemPrompt: "你是一位性格温和、幽默的职业围棋九段教练。请用专业、简练的围棋术语（如脱先、方向错误、太缓、急所、味道恶劣等），向人类玩家解释为什么他的这步棋是恶手，以及 KataGo 推荐的最佳选点好在哪里。控制在 80 字以内，直接说出棋理，不要说废话。",
            userPrompt: prompt
        )
    }

    func requestTeachingExplanation(input: TeachingInput) -> AsyncThrowingStream<String, Error> {
        let pvText = input.keyPV.isEmpty ? "引擎未返回主变，请仅解释大致思路" : input.keyPV.prefix(6).joined(separator: " -> ")
        let isTop5Text = input.playedRank != nil ? "该手在候选第 \(input.playedRank! + 1) 位" : "该手未进入前五候选"

        let systemPrompt = """
        你是一位专业、耐心的职业围棋九段导师。请基于给定的 KataGo 结构化分析数据，教导人类玩家如何思考。
        禁止自己编造棋谱和主变，只能使用提供的数据进行讲解。
        你必须严格输出以下固定结构（包含 Markdown 的 ### 小标题），不要增加多余的开头和结尾：

        ### 局面主题
        （1句话：说明此时局面的焦点，例如：大场、攻弱、补棋、收官等）

        ### 你这手的意图可能是
        （1句话：站在玩家角度，推测他下在 \(input.playedMove) 的意图）

        ### 问题出在
        （结合错误类型【\(input.mistakeType)】讲解这手棋为何不好：胜率掉了 \(String(format: "%.1f%%", input.wrDrop*100))，\(isTop5Text)）

        ### 更好的方案
        （解释最佳选点 \(input.bestCandidate.move) 为什么更好，并简述主变：\(pvText)）

        ### 下次检查清单
        （提供3条简短的避坑检查单，让玩家以后遇到类似局面先问自己几个问题）
        """

        return streamChatCompletion(
            systemPrompt: systemPrompt,
            userPrompt: "当前是第 \(input.turn) 手，\(input.toPlay)方落子在 \(input.playedMove)。"
        )
    }

    private func streamChatCompletion(systemPrompt: String, userPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (result, response) = try await URLSession.shared.bytes(for: makeStreamingRequest(systemPrompt: systemPrompt, userPrompt: userPrompt))
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: URLError(.badServerResponse))
                        return
                    }

                    for try await line in result.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" { break }
                        if let content = Self.extractDeltaContent(from: jsonString) {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makeStreamingRequest(systemPrompt: String, userPrompt: String) throws -> URLRequest {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": true
        ])
        return request
    }

    private static func extractDeltaContent(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else {
            return nil
        }
        return delta["content"] as? String
    }
}
