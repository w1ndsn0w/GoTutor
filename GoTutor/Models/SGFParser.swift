//
//  SGFParser.swift
//  GoTutor
//
//  Created by 袁守航 on 2026/3/16.
//

import Foundation

// MARK: - SGF 数据模型 (使用 struct 保证 Sendable 并发安全)
struct SGFNode: Sendable {
    // 节点的属性字典，例如：["B": ["pd"], "C": ["这是星位", "好棋"]]
    var properties: [String: [String]] = [:]
    // 变化图分支。如果是普通对局，通常只有1个元素；如果是死活题，可能会有多个。
    var children: [SGFNode] = []
}

struct SGFGameTree: Sendable {
    var rootNode: SGFNode
}

// MARK: - 解析引擎
struct SGFParser: Sendable {
    
    enum SGFError: Error {
        case emptyString
        case invalidFormat
        case parsingFailed(String)
    }
    
    // 核心解析入口
    static func parse(string: String) throws -> SGFGameTree {
        let content = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw SGFError.emptyString }
        
        // 使用一个内部类来方便地构建树（构建完成后转为安全的 struct）
        let rootBuilder = NodeBuilder()
        var currentBuilder: NodeBuilder? = nil
        var nodeStack: [NodeBuilder] = []
        
        var currentIndex = content.startIndex
        
        // 词法分析游标
        while currentIndex < content.endIndex {
            let char = content[currentIndex]
            
            switch char {
            case "(":
                // 开启一个新分支
                nodeStack.append(currentBuilder ?? rootBuilder)
                currentIndex = content.index(after: currentIndex)
                
            case ")":
                // 结束当前分支，回退到上一层
                guard !nodeStack.isEmpty else { throw SGFError.invalidFormat }
                currentBuilder = nodeStack.popLast()
                currentIndex = content.index(after: currentIndex)
                
            case ";":
                // 创建一个新节点（一手棋或一个配置节点）
                let newNode = NodeBuilder()
                if currentBuilder == nil {
                    // 这是整个树的根节点
                    rootBuilder.children.append(newNode)
                } else {
                    currentBuilder?.children.append(newNode)
                }
                currentBuilder = newNode
                currentIndex = content.index(after: currentIndex)
                
            case let c where c.isLetter && c.isUppercase:
                // 解析属性标识符（如 B, W, C, AW, AB 等大写字母）
                guard let targetNode = currentBuilder else {
                    currentIndex = content.index(after: currentIndex)
                    continue
                }
                
                var propIdent = ""
                while currentIndex < content.endIndex, content[currentIndex].isLetter, content[currentIndex].isUppercase {
                    propIdent.append(content[currentIndex])
                    currentIndex = content.index(after: currentIndex)
                }
                
                // 解析属性的值（中括号里的内容，支持多个，如 [ab][cd]）
                var propValues: [String] = []
                while currentIndex < content.endIndex {
                    // 跳过空白符
                    while currentIndex < content.endIndex, content[currentIndex].isWhitespace {
                        currentIndex = content.index(after: currentIndex)
                    }
                    
                    if currentIndex < content.endIndex, content[currentIndex] == "[" {
                        currentIndex = content.index(after: currentIndex) // 跳过 '['
                        var value = ""
                        var isEscaped = false // 处理 SGF 里的转义字符 \]
                        
                        while currentIndex < content.endIndex {
                            let valChar = content[currentIndex]
                            if isEscaped {
                                value.append(valChar)
                                isEscaped = false
                            } else if valChar == "\\" {
                                isEscaped = true
                            } else if valChar == "]" {
                                currentIndex = content.index(after: currentIndex) // 跳过 ']'
                                break
                            } else {
                                value.append(valChar)
                            }
                            currentIndex = content.index(after: currentIndex)
                        }
                        propValues.append(value)
                    } else {
                        break // 没有中括号了，说明这个属性的值结束了
                    }
                }
                targetNode.properties[propIdent] = propValues
                
            default:
                // 跳过其他无关字符（如换行符）
                currentIndex = content.index(after: currentIndex)
            }
        }
        
        guard let firstRealNode = rootBuilder.children.first else {
            throw SGFError.parsingFailed("没有找到有效的棋谱节点")
        }
        
        return SGFGameTree(rootNode: firstRealNode.toSGFNode())
    }
}

// 内部构建器（Class 方便处理树形嵌套的引用，构建完后抛弃）
private class NodeBuilder {
    var properties: [String: [String]] = [:]
    var children: [NodeBuilder] = []
    
    // 递归将 Class 树转换为 Struct 树 (剥离引用，实现并发安全)
    func toSGFNode() -> SGFNode {
        return SGFNode(properties: properties, children: children.map { $0.toSGFNode() })
    }
}
