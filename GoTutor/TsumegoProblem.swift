//
//  TsumegoProblem.swift
//  GoTutor
//
//  Created by 袁守航 on 2026/3/16.
//
import Foundation

// MARK: - 单个死活题模型
struct TsumegoProblem: Identifiable, Hashable {
    let id = UUID()
    let number: Int          // 题号
    let title: String        // 题目描述
    let difficulty: String   // 难度
    let sgfContent: String   // 题目的 SGF 原始内容
    let firstToPlay: Stone   // 谁先走（通常是黑先）
}

// MARK: - 模拟题库数据
struct TsumegoBank {
    static let beginnerProblems: [TsumegoProblem] = [
        TsumegoProblem(
            number: 1,
            title: "黑先杀白：最简单的扑",
            difficulty: "30级",
            // 这是一个真实的死活题SGF：黑棋走在 a 就能提掉白棋
            sgfContent: "(;GM[1]FF[4]SZ[19]AB[pa][pb][pc][ob][oc]AW[qa][qb][qc][rc]C[黑先杀白];B[ra]C[正解！白棋被杀。])",
            firstToPlay: .black
        ),
        TsumegoProblem(
            number: 2,
            title: "黑先做活：寻找眼位",
            difficulty: "25级",
            sgfContent: "(;GM[1]FF[4]SZ[19]AB[cr][dr][er][fq][gq][hq]AW[cq][dq][eq][ep][fp][gp][hp][iq][ir][hr]C[黑先做活];B[fr]C[正解！黑棋成功做活。])",
            firstToPlay: .black
        ),
        TsumegoProblem(
            number: 3,
            title: "黑先杀白：经典聚杀",
            difficulty: "20级",
            sgfContent: "(;GM[1]FF[4]SZ[19]AB[aa][ba][ca][da][db][dc][dd][cd][bd][ad]AW[ab][bb][cb][bc][cc]C[黑先杀白（直三聚杀）];B[ac]C[正解！一击致命。])",
            firstToPlay: .black
        )
    ]
}
