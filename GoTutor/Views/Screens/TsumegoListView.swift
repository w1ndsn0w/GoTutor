//
//  TsumegoListView.swift
//  GoTutor
//
//  Created by 袁守航 on 2026/3/16.
//

import SwiftUI

struct TsumegoListView: View {
    @Environment(\.dismiss) private var dismiss

    private static let defaultProblems = TsumegoBank.beginnerProblems
    private let problems = TsumegoListView.defaultProblems
    var showsCloseButton = false
    @State private var selectedProblemNumber: Int
    @State private var session: TsumegoSession
    @State private var progressByNumber: [Int: TsumegoProblemProgress] = [:]

    init(showsCloseButton: Bool = false) {
        let firstProblem = TsumegoListView.defaultProblems[0]
        self.showsCloseButton = showsCloseButton
        _selectedProblemNumber = State(initialValue: firstProblem.number)
        _session = State(initialValue: TsumegoSession(problem: firstProblem))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.regularMaterial)

                Divider()

                if geometry.size.width < 760 {
                    compactLayout
                } else {
                    regularLayout
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private var selectedIndex: Int {
        problems.firstIndex { $0.number == selectedProblemNumber } ?? 0
    }

    private var selectedProblem: TsumegoProblem {
        problems[selectedIndex]
    }

    private var solvedCount: Int {
        progressByNumber.values.filter(\.isSolved).count
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("死活题训练")
                    .font(.system(size: 24, weight: .semibold))
                Text("入门题库 · \(solvedCount)/\(problems.count) 已完成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                TsumegoSummaryPill(title: "当前", value: "\(selectedProblem.number)")
                TsumegoSummaryPill(title: "尝试", value: "\(session.attempts)")

                if showsCloseButton {
                    Button {
                        dismiss()
                    } label: {
                        Label("回到棋盘", systemImage: "xmark")
                    }
                    .buttonStyle(HeaderButtonStyle())
                }
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 0) {
            problemSidebar
                .frame(width: 320)
                .background(Color(UIColor.secondarySystemGroupedBackground))

            Divider()

            solvingArea
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(problems) { problem in
                        Button {
                            selectProblem(problem)
                        } label: {
                            TsumegoProblemChip(
                                problem: problem,
                                isSelected: problem.number == selectedProblemNumber,
                                progress: progressByNumber[problem.number]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))

            Divider()

            ScrollView {
                solvingContent(axis: .vertical)
                    .padding()
            }
        }
    }

    private var problemSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("题库", systemImage: "list.bullet")
                    .font(.headline)
                Spacer()
                Text("\(problems.count) 题")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(problems) { problem in
                        Button {
                            selectProblem(problem)
                        } label: {
                            TsumegoProblemRow(
                                problem: problem,
                                isSelected: problem.number == selectedProblemNumber,
                                progress: progressByNumber[problem.number]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
        }
    }

    private var solvingArea: some View {
        ScrollView {
            solvingContent(axis: .horizontal)
                .padding(24)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func solvingContent(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(alignment: .top, spacing: 24) {
                boardStage
                    .frame(maxWidth: .infinity)

                inspectorPanel
                    .frame(width: 310)
            }
        } else {
            VStack(spacing: 18) {
                boardStage
                inspectorPanel
            }
        }
    }

    private var boardStage: some View {
        VStack(spacing: 18) {
            problemHeader

            if let errorMessage = session.errorMessage {
                ContentUnavailableView("题目加载失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                TsumegoBoardView(
                    board: session.board,
                    region: session.region,
                    currentPlayer: session.currentPlayer,
                    lastMove: session.lastMove,
                    hintPoint: session.hintPoint,
                    onTap: handleMove
                )
                .frame(maxWidth: 620)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var problemHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(selectedProblem.number)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(selectedProblem.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(selectedProblem.difficulty, systemImage: "speedometer")
                    Label(selectedProblem.firstToPlay == .black ? "黑先" : "白先", systemImage: "circle.lefthalf.filled")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            feedbackPanel

            VStack(spacing: 10) {
                Button {
                    resetCurrentProblem()
                } label: {
                    Label("重来", systemImage: "arrow.counterclockwise")
                }

                Button {
                    session.revealHint()
                } label: {
                    Label("提示", systemImage: "lightbulb")
                }
                .disabled(session.isSolved)

                Button {
                    goToNextProblem()
                } label: {
                    Label(selectedIndex == problems.count - 1 ? "回到第一题" : "下一题", systemImage: "arrow.right")
                }
            }
            .buttonStyle(CleanWhiteButtonStyle())

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                TsumegoInfoRow(title: "进度", value: progressByNumber[selectedProblem.number]?.isSolved == true ? "已完成" : "练习中")
                TsumegoInfoRow(title: "难度", value: selectedProblem.difficulty)
                TsumegoInfoRow(title: "先手", value: selectedProblem.firstToPlay == .black ? "黑棋" : "白棋")
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.16), lineWidth: 1))
    }

    private var feedbackPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.status.iconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(session.status.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.status.title)
                    .font(.headline)
                Text(session.feedback)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(UIColor.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func selectProblem(_ problem: TsumegoProblem) {
        selectedProblemNumber = problem.number
        session = TsumegoSession(problem: problem)
    }

    private func resetCurrentProblem() {
        session.reset()
    }

    private func handleMove(_ point: Point) {
        session.play(at: point)
        if session.isSolved {
            progressByNumber[selectedProblem.number] = TsumegoProblemProgress(isSolved: true, attempts: session.attempts)
        }
    }

    private func goToNextProblem() {
        let nextIndex = selectedIndex == problems.count - 1 ? 0 : selectedIndex + 1
        selectProblem(problems[nextIndex])
    }
}

// MARK: - 做题界面
struct TsumegoSolvingView: View {
    let problem: TsumegoProblem
    @State private var session: TsumegoSession

    init(problem: TsumegoProblem) {
        self.problem = problem
        _session = State(initialValue: TsumegoSession(problem: problem))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if let errorMessage = session.errorMessage {
                    ContentUnavailableView("题目加载失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                        .padding(.top, 40)
                } else {
                    TsumegoBoardView(
                        board: session.board,
                        region: session.region,
                        currentPlayer: session.currentPlayer,
                        lastMove: session.lastMove,
                        hintPoint: session.hintPoint,
                        onTap: { point in session.play(at: point) }
                    )
                    .frame(maxWidth: 560)
                    .padding(.horizontal)

                    feedbackPanel
                    actionBar
                }
            }
            .padding(.vertical, 18)
        }
        .navigationTitle("第 \(problem.number) 题")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(problem.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Label(problem.difficulty, systemImage: "speedometer")
                Label(problem.firstToPlay == .black ? "黑先" : "白先", systemImage: "circle.lefthalf.filled")
                if session.attempts > 0 {
                    Label("\(session.attempts) 次尝试", systemImage: "arrow.counterclockwise")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var feedbackPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.status.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(session.status.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.status.title)
                    .font(.headline)
                Text(session.feedback)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                session.reset()
            } label: {
                Label("重来", systemImage: "arrow.counterclockwise")
            }

            Button {
                session.revealHint()
            } label: {
                Label("提示", systemImage: "lightbulb")
            }
            .disabled(session.isSolved)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

#Preview {
    TsumegoListView()
}

private struct TsumegoProblemProgress {
    let isSolved: Bool
    let attempts: Int
}

private struct TsumegoSummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TsumegoProblemRow: View {
    let problem: TsumegoProblem
    let isSelected: Bool
    let progress: TsumegoProblemProgress?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(problem.number)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .accentColor)
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(problem.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(problem.difficulty)
                    Text(problem.firstToPlay == .black ? "黑先" : "白先")
                    if let progress, progress.isSolved {
                        Label(progress.attempts == 0 ? "完成" : "\(progress.attempts) 次", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color(UIColor.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1))
    }
}

private struct TsumegoProblemChip: View {
    let problem: TsumegoProblem
    let isSelected: Bool
    let progress: TsumegoProblemProgress?

    var body: some View {
        HStack(spacing: 8) {
            Text("\(problem.number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(isSelected ? .white : .accentColor)

            Text(problem.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if progress?.isSolved == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1))
    }
}

private struct TsumegoInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - 死活题状态

private struct TsumegoSession {
    private let problem: TsumegoProblem
    private let rootNode: SGFNode?
    private let initialBoard: [[Stone]]

    var board: [[Stone]]
    var region: TsumegoBoardRegion
    var currentPlayer: Stone
    var currentNode: SGFNode?
    var lastMove: Point?
    var hintPoint: Point?
    var attempts = 0
    var status: TsumegoStatus = .ready
    var feedback: String
    var errorMessage: String?

    var isSolved: Bool {
        if case .solved = status { return true }
        return false
    }

    init(problem: TsumegoProblem) {
        self.problem = problem
        self.currentPlayer = problem.firstToPlay
        self.feedback = problem.firstToPlay == .black ? "黑方落子" : "白方落子"

        do {
            let gameTree = try SGFParser.parse(string: problem.sgfContent)
            let root = gameTree.rootNode
            let boardSize = TsumegoSession.boardSize(from: root)
            let placedStones = TsumegoSession.setupStones(from: root, boardSize: boardSize)
            let board = TsumegoSession.makeBoard(size: boardSize, stones: placedStones)
            let pointsForRegion = placedStones.map(\.point) + TsumegoSession.solutionPoints(from: root, boardSize: boardSize)

            self.rootNode = root
            self.initialBoard = board
            self.board = board
            self.currentNode = root
            self.region = TsumegoBoardRegion(points: pointsForRegion, boardSize: boardSize)
            self.errorMessage = nil
        } catch {
            self.rootNode = nil
            self.initialBoard = []
            self.board = []
            self.currentNode = nil
            self.region = TsumegoBoardRegion.fullBoard(size: 19)
            self.errorMessage = error.localizedDescription
            self.status = .wrong
            self.feedback = "SGF 解析失败"
        }
    }

    mutating func reset() {
        guard rootNode != nil else { return }
        board = initialBoard
        currentNode = rootNode
        currentPlayer = problem.firstToPlay
        lastMove = nil
        hintPoint = nil
        attempts = 0
        status = .ready
        feedback = problem.firstToPlay == .black ? "黑方落子" : "白方落子"
    }

    mutating func revealHint() {
        guard !isSolved, let answer = firstAnswerPoint() else { return }
        hintPoint = answer
        status = .hint
        feedback = "关键点已标出"
    }

    mutating func play(at point: Point) {
        guard !isSolved else { return }
        guard point.isOnBoard(size: board.count) else { return }
        guard board[point.r][point.c] == .empty else {
            status = .wrong
            feedback = "这里已经有棋子"
            return
        }

        guard let answerNode = matchingAnswerNode(for: point) else {
            attempts += 1
            hintPoint = nil
            status = .wrong
            feedback = "这手不是本题要点"
            return
        }

        guard place(point, for: currentPlayer) else {
            attempts += 1
            hintPoint = nil
            status = .wrong
            feedback = "这手在当前局面下不成立"
            return
        }

        currentNode = answerNode
        hintPoint = nil
        advanceAfterCorrectMove()
    }

    private func firstAnswerPoint() -> Point? {
        currentNode?.children.compactMap { $0.movePoint(for: currentPlayer, boardSize: board.count) }.first
    }

    private func matchingAnswerNode(for point: Point) -> SGFNode? {
        currentNode?.children.first { child in
            child.movePoint(for: currentPlayer, boardSize: board.count) == point
        }
    }

    private mutating func advanceAfterCorrectMove() {
        if let responseNode = currentNode?.children.first(where: { $0.movePoint(for: currentPlayer, boardSize: board.count) != nil }),
           let responsePoint = responseNode.movePoint(for: currentPlayer, boardSize: board.count),
           place(responsePoint, for: currentPlayer) {
            currentNode = responseNode
            if firstAnswerPoint() == nil {
                status = .solved
                feedback = "正解，变化到此完成"
            } else {
                status = .correct
                feedback = currentPlayer == problem.firstToPlay ? "对方已应一手，继续" : "正解，继续"
            }
            return
        }

        status = .solved
        feedback = "正解"
    }

    @discardableResult
    private mutating func place(_ point: Point, for color: Stone) -> Bool {
        guard point.isOnBoard(size: board.count), board[point.r][point.c] == .empty else { return false }

        let previousBoard = board
        board[point.r][point.c] = color

        for neighbor in neighbors(of: point) where board[neighbor.r][neighbor.c] == color.opponent {
            let group = collectGroup(start: neighbor)
            if liberties(of: group) == 0 {
                for capturedPoint in group {
                    board[capturedPoint.r][capturedPoint.c] = .empty
                }
            }
        }

        let ownGroup = collectGroup(start: point)
        guard liberties(of: ownGroup) > 0 else {
            board = previousBoard
            return false
        }

        lastMove = point
        currentPlayer = color.opponent
        return true
    }

    private func neighbors(of point: Point) -> [Point] {
        [
            Point(r: point.r - 1, c: point.c),
            Point(r: point.r + 1, c: point.c),
            Point(r: point.r, c: point.c - 1),
            Point(r: point.r, c: point.c + 1)
        ].filter { $0.isOnBoard(size: board.count) }
    }

    private func collectGroup(start: Point) -> [Point] {
        let color = board[start.r][start.c]
        guard color != .empty else { return [] }

        var visited: Set<Point> = [start]
        var stack = [start]

        while let point = stack.popLast() {
            for neighbor in neighbors(of: point) where board[neighbor.r][neighbor.c] == color && !visited.contains(neighbor) {
                visited.insert(neighbor)
                stack.append(neighbor)
            }
        }

        return Array(visited)
    }

    private func liberties(of group: [Point]) -> Int {
        var liberties: Set<Point> = []
        for point in group {
            for neighbor in neighbors(of: point) where board[neighbor.r][neighbor.c] == .empty {
                liberties.insert(neighbor)
            }
        }
        return liberties.count
    }

    private static func boardSize(from root: SGFNode) -> Int {
        guard let value = root.properties["SZ"]?.first,
              let size = Int(value.split(separator: ":").first.map(String.init) ?? value),
              (2...19).contains(size) else {
            return 19
        }
        return size
    }

    private static func setupStones(from root: SGFNode, boardSize: Int) -> [(point: Point, stone: Stone)] {
        var stones: [(Point, Stone)] = []

        for value in root.properties["AB"] ?? [] {
            if let point = Point(sgf: value, boardSize: boardSize) {
                stones.append((point, .black))
            }
        }

        for value in root.properties["AW"] ?? [] {
            if let point = Point(sgf: value, boardSize: boardSize) {
                stones.append((point, .white))
            }
        }

        return stones
    }

    private static func makeBoard(size: Int, stones: [(point: Point, stone: Stone)]) -> [[Stone]] {
        var board = Array(repeating: Array(repeating: Stone.empty, count: size), count: size)
        for item in stones where item.point.isOnBoard(size: size) {
            board[item.point.r][item.point.c] = item.stone
        }
        return board
    }

    private static func solutionPoints(from node: SGFNode, boardSize: Int) -> [Point] {
        var points: [Point] = []

        if let blackMove = node.properties["B"]?.first, let point = Point(sgf: blackMove, boardSize: boardSize) {
            points.append(point)
        }
        if let whiteMove = node.properties["W"]?.first, let point = Point(sgf: whiteMove, boardSize: boardSize) {
            points.append(point)
        }

        for child in node.children {
            points.append(contentsOf: solutionPoints(from: child, boardSize: boardSize))
        }

        return points
    }
}

private enum TsumegoStatus {
    case ready
    case correct
    case wrong
    case hint
    case solved

    var title: String {
        switch self {
        case .ready: return "等待落子"
        case .correct: return "正解"
        case .wrong: return "再想想"
        case .hint: return "提示"
        case .solved: return "已完成"
        }
    }

    var iconName: String {
        switch self {
        case .ready: return "scope"
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        case .hint: return "lightbulb.fill"
        case .solved: return "rosette"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .secondary
        case .correct: return .green
        case .wrong: return .red
        case .hint: return .orange
        case .solved: return .blue
        }
    }
}

private struct TsumegoBoardRegion {
    let minRow: Int
    let maxRow: Int
    let minCol: Int
    let maxCol: Int

    var rowCount: Int { maxRow - minRow + 1 }
    var colCount: Int { maxCol - minCol + 1 }

    static func fullBoard(size: Int) -> TsumegoBoardRegion {
        TsumegoBoardRegion(minRow: 0, maxRow: size - 1, minCol: 0, maxCol: size - 1)
    }

    init(minRow: Int, maxRow: Int, minCol: Int, maxCol: Int) {
        self.minRow = minRow
        self.maxRow = maxRow
        self.minCol = minCol
        self.maxCol = maxCol
    }

    init(points: [Point], boardSize: Int) {
        guard let first = points.first else {
            self = .fullBoard(size: boardSize)
            return
        }

        let rows = points.map(\.r)
        let cols = points.map(\.c)
        var minRow = max(0, (rows.min() ?? first.r) - 1)
        var maxRow = min(boardSize - 1, (rows.max() ?? first.r) + 1)
        var minCol = max(0, (cols.min() ?? first.c) - 1)
        var maxCol = min(boardSize - 1, (cols.max() ?? first.c) + 1)
        let targetSpan = min(boardSize - 1, max(6, max(maxRow - minRow, maxCol - minCol)))

        TsumegoBoardRegion.expand(minValue: &minRow, maxValue: &maxRow, targetSpan: targetSpan, boardSize: boardSize)
        TsumegoBoardRegion.expand(minValue: &minCol, maxValue: &maxCol, targetSpan: targetSpan, boardSize: boardSize)

        self.minRow = minRow
        self.maxRow = maxRow
        self.minCol = minCol
        self.maxCol = maxCol
    }

    private static func expand(minValue: inout Int, maxValue: inout Int, targetSpan: Int, boardSize: Int) {
        while maxValue - minValue < targetSpan {
            if minValue > 0 {
                minValue -= 1
            }
            if maxValue - minValue >= targetSpan { break }
            if maxValue < boardSize - 1 {
                maxValue += 1
            }
            if minValue == 0 && maxValue == boardSize - 1 { break }
        }
    }
}

private struct TsumegoBoardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let board: [[Stone]]
    let region: TsumegoBoardRegion
    let currentPlayer: Stone
    let lastMove: Point?
    let hintPoint: Point?
    let onTap: (Point) -> Void

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let cellSize = dimension / CGFloat(max(region.rowCount, region.colCount))
            let margin = cellSize / 2

            ZStack {
                boardBackground

                grid(cellSize: cellSize, margin: margin)
                stones(cellSize: cellSize, margin: margin)
                hintMark(cellSize: cellSize, margin: margin)
                lastMoveMark(cellSize: cellSize, margin: margin)
            }
            .frame(width: dimension, height: dimension)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                let localCol = Int(round((location.x - margin) / cellSize))
                let localRow = Int(round((location.y - margin) / cellSize))
                let point = Point(r: region.minRow + localRow, c: region.minCol + localCol)
                if point.r >= region.minRow,
                   point.r <= region.maxRow,
                   point.c >= region.minCol,
                   point.c <= region.maxCol {
                    onTap(point)
                }
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(currentPlayer == .black ? "黑方落子" : "白方落子")
    }

    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.86, green: 0.66, blue: 0.41))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 6, x: 0, y: 3)
    }

    private func grid(cellSize: CGFloat, margin: CGFloat) -> some View {
        Path { path in
            let rowEnd = margin + CGFloat(region.rowCount - 1) * cellSize
            let colEnd = margin + CGFloat(region.colCount - 1) * cellSize

            for row in 0..<region.rowCount {
                let y = margin + CGFloat(row) * cellSize
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: colEnd, y: y))
            }

            for col in 0..<region.colCount {
                let x = margin + CGFloat(col) * cellSize
                path.move(to: CGPoint(x: x, y: margin))
                path.addLine(to: CGPoint(x: x, y: rowEnd))
            }
        }
        .stroke(Color.black.opacity(0.62), lineWidth: 1)
    }

    private func stones(cellSize: CGFloat, margin: CGFloat) -> some View {
        ForEach(region.minRow...region.maxRow, id: \.self) { row in
            ForEach(region.minCol...region.maxCol, id: \.self) { col in
                let stone = board[row][col]
                if stone != .empty {
                    Circle()
                        .fill(stone == .black ? Color.black : Color.white)
                        .shadow(color: .black.opacity(0.28), radius: 1.5, x: 1, y: 1)
                        .overlay(Circle().stroke(stone == .white ? Color.black.opacity(0.26) : Color.white.opacity(0.12), lineWidth: 0.7))
                        .frame(width: cellSize * 0.92, height: cellSize * 0.92)
                        .position(position(for: Point(r: row, c: col), cellSize: cellSize, margin: margin))
                }
            }
        }
    }

    private func hintMark(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if let hintPoint, contains(hintPoint) {
                Circle()
                    .stroke(Color.orange, lineWidth: 3)
                    .frame(width: cellSize * 0.62, height: cellSize * 0.62)
                    .shadow(color: .orange.opacity(0.55), radius: 5)
                    .position(position(for: hintPoint, cellSize: cellSize, margin: margin))
            }
        }
    }

    private func lastMoveMark(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if let lastMove, contains(lastMove) {
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: cellSize * 0.42, height: cellSize * 0.42)
                    .position(position(for: lastMove, cellSize: cellSize, margin: margin))
            }
        }
    }

    private func position(for point: Point, cellSize: CGFloat, margin: CGFloat) -> CGPoint {
        CGPoint(
            x: margin + CGFloat(point.c - region.minCol) * cellSize,
            y: margin + CGFloat(point.r - region.minRow) * cellSize
        )
    }

    private func contains(_ point: Point) -> Bool {
        point.r >= region.minRow && point.r <= region.maxRow && point.c >= region.minCol && point.c <= region.maxCol
    }
}

private extension SGFNode {
    func movePoint(for player: Stone, boardSize: Int) -> Point? {
        let key = player == .black ? "B" : "W"
        guard let value = properties[key]?.first else { return nil }
        return Point(sgf: value, boardSize: boardSize)
    }
}
