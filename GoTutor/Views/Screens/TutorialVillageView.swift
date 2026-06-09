import SwiftUI

struct TutorialVillageView: View {
    enum Stage {
        case welcome
        case lesson
        case completed
    }

    let isFirstLaunch: Bool
    let onSkip: () -> Void
    let onCompleted: () -> Void
    let onStartGame: () -> Void
    let onOpenTsumego: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var stage: Stage
    @State private var lessonIndex = 0
    @State private var boardState: TutorialBoardState
    @State private var feedback: TutorialFeedback = .idle
    @State private var hasSolvedCurrentLesson = false
    @State private var hasMarkedCompleted = false
    @State private var demoFrameIndex = 0

    private let lessons = TutorialLesson.all

    init(
        isFirstLaunch: Bool,
        onSkip: @escaping () -> Void,
        onCompleted: @escaping () -> Void,
        onStartGame: @escaping () -> Void,
        onOpenTsumego: @escaping () -> Void
    ) {
        self.isFirstLaunch = isFirstLaunch
        self.onSkip = onSkip
        self.onCompleted = onCompleted
        self.onStartGame = onStartGame
        self.onOpenTsumego = onOpenTsumego

        let initialStage: Stage = isFirstLaunch ? .welcome : .lesson
        _stage = State(initialValue: initialStage)
        _boardState = State(initialValue: TutorialBoardState(lesson: TutorialLesson.all[0]))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("新手村")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if stage == .lesson && !isFirstLaunch {
                        lessonPickerMenu
                    }

                    Button("退出") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .welcome:
            TutorialWelcomeView(
                onStart: { stage = .lesson },
                onSkip: onSkip
            )
        case .lesson:
            lessonScreen
        case .completed:
            TutorialCompletionView(
                onRestart: restartLessons,
                onStartGame: onStartGame,
                onOpenTsumego: onOpenTsumego
            )
        }
    }

    private var progressBadge: some View {
        Text("\(lessonIndex + 1)/\(lessons.count)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(UIColor.tertiarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.16), lineWidth: 1))
    }

    private var lessonPickerMenu: some View {
        Menu {
            ForEach(lessons.indices, id: \.self) { index in
                Button(action: { jumpToLesson(index) }) {
                    Label(
                        "第 \(lessons[index].id) 关：\(lessons[index].title)",
                        systemImage: index == lessonIndex ? "checkmark.circle.fill" : "\(index + 1).circle"
                    )
                }
            }
        } label: {
            Label("选关", systemImage: "list.bullet")
        }
        .font(.body.weight(.semibold))
    }

    private var lesson: TutorialLesson {
        lessons[lessonIndex]
    }

    private var lessonScreen: some View {
        ScrollView {
            VStack(spacing: 18) {
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 18) {
                        boardPanel
                            .frame(maxWidth: 520)
                        lessonPanel
                            .frame(width: 360)
                    }
                    .frame(maxWidth: 940)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        lessonPanel
                        boardPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }

                navigationControls
                    .frame(maxWidth: horizontalSizeClass == .regular ? 940 : .infinity)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: lessonIndex) { _, _ in
            resetCurrentLesson()
        }
    }

    private var lessonPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(.blue)
                Text("第 \(lesson.id) 关")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                playerPill
            }

            Text(lesson.title)
                .font(.system(size: 24, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(lesson.explanation)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Label(lesson.task, systemImage: taskSystemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            feedbackView

            if lesson.action == .watchDemo {
                demoControls
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }

    private var playerPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(boardState.currentPlayer == .black ? Color.black : Color.white)
                .overlay(Circle().stroke(Color.secondary.opacity(0.7), lineWidth: 1))
                .frame(width: 10, height: 10)
            Text(boardState.currentPlayer == .black ? "黑先" : "白先")
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(UIColor.tertiarySystemGroupedBackground), in: Capsule())
    }

    private var taskSystemImage: String {
        lesson.action == .watchDemo ? "play.rectangle" : "hand.tap"
    }

    @ViewBuilder
    private var feedbackView: some View {
        switch feedback {
        case .idle:
            Label(idleFeedbackText, systemImage: "circle.dashed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .wrong(let message):
            Label(message, systemImage: "lightbulb")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.orange)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.green)
        }
    }

    private var idleFeedbackText: String {
        lesson.action == .watchDemo ? "请按演示按钮看完这一关" : "请点击棋盘完成任务"
    }

    private var demoControls: some View {
        HStack(spacing: 12) {
            Button(action: previousDemoFrame) {
                Label("上一步", systemImage: "chevron.left")
            }
            .disabled(demoFrameIndex == 0)

            Button(action: advanceDemo) {
                Label(demoPrimaryButtonTitle, systemImage: hasSolvedCurrentLesson ? "checkmark.circle" : "play.fill")
            }
            .disabled(hasSolvedCurrentLesson)
        }
        .buttonStyle(CleanWhiteButtonStyle())
        .padding(.top, 2)
    }

    private var demoPrimaryButtonTitle: String {
        if hasSolvedCurrentLesson { return "已看懂" }
        return demoFrameIndex >= lesson.demoFrames.count - 1 ? "我看懂了" : "下一步演示"
    }

    private var boardPanel: some View {
        VStack(spacing: 12) {
            TutorialBoardView(
                board: boardState.board,
                lastMove: currentDemoFrame?.lastMove ?? boardState.lastMove,
                highlightedPoints: currentDemoFrame?.highlightPoints ?? [],
                blackTerritory: currentDemoFrame?.blackTerritory ?? [],
                whiteTerritory: currentDemoFrame?.whiteTerritory ?? [],
                hintPoint: hintPoint,
                successPoint: hasSolvedCurrentLesson ? lesson.correctPoint : nil,
                isInteractionEnabled: lesson.action != .watchDemo && !hasSolvedCurrentLesson,
                onTap: handleBoardTap
            )
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))

            Text(boardCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var boardCaption: String {
        if let currentDemoFrame {
            return currentDemoFrame.caption
        }

        switch lesson.action {
        case .placeStone:
            return "点击正确交叉点后，教学棋盘会演示落子和提子。"
        case .inspectPoint:
            return "这一关只需要辨认棋盘上的关键交叉点。"
        case .forbiddenPoint:
            return "这一关点的是不能落子的点，棋盘不会真的放下棋子。"
        case .watchDemo:
            return "按演示按钮观察棋盘变化。"
        }
    }

    private var hintPoint: Point? {
        if case .wrong = feedback {
            return lesson.correctPoint
        }
        return nil
    }

    private var currentDemoFrame: TutorialDemoFrame? {
        guard lesson.action == .watchDemo, lesson.demoFrames.indices.contains(demoFrameIndex) else { return nil }
        return lesson.demoFrames[demoFrameIndex]
    }

    private var navigationControls: some View {
        HStack(spacing: 12) {
            Button(action: previousLesson) {
                Label("上一关", systemImage: "chevron.left")
            }
            .disabled(lessonIndex == 0)

            Button(action: resetCurrentLesson) {
                Label("重试", systemImage: "arrow.counterclockwise")
            }

            Button(action: nextLesson) {
                Label(nextButtonTitle, systemImage: lessonIndex == lessons.count - 1 ? "checkmark" : "chevron.right")
            }
            .disabled(!hasSolvedCurrentLesson)
        }
        .buttonStyle(CleanWhiteButtonStyle())
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }

    private var nextButtonTitle: String {
        lessonIndex == lessons.count - 1 ? "完成" : "下一关"
    }

    private func handleBoardTap(_ point: Point) {
        guard !hasSolvedCurrentLesson else { return }
        guard let correctPoint = lesson.correctPoint else { return }

        guard point == correctPoint else {
            feedback = .wrong(lesson.wrongHint)
            return
        }

        switch lesson.action {
        case .placeStone:
            if !boardState.place(point) {
                feedback = .wrong("这手在当前局面下不成立，再观察一下气。")
                return
            }
        case .inspectPoint, .forbiddenPoint:
            boardState.lastMove = point
        case .watchDemo:
            return
        }

        hasSolvedCurrentLesson = true
        feedback = .success(lesson.successFeedback)
    }

    private func advanceDemo() {
        if demoFrameIndex < lesson.demoFrames.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                demoFrameIndex += 1
                boardState = TutorialBoardState(lesson: lesson, demoFrameIndex: demoFrameIndex)
                feedback = .idle
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            hasSolvedCurrentLesson = true
            feedback = .success(lesson.successFeedback)
        }
    }

    private func previousDemoFrame() {
        guard demoFrameIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            demoFrameIndex -= 1
            boardState = TutorialBoardState(lesson: lesson, demoFrameIndex: demoFrameIndex)
            if hasSolvedCurrentLesson {
                hasSolvedCurrentLesson = false
                feedback = .idle
            }
        }
    }

    private func previousLesson() {
        guard lessonIndex > 0 else { return }
        lessonIndex -= 1
    }

    private func nextLesson() {
        guard hasSolvedCurrentLesson else { return }
        if lessonIndex < lessons.count - 1 {
            lessonIndex += 1
        } else {
            markCompletedIfNeeded()
            stage = .completed
        }
    }

    private func restartLessons() {
        lessonIndex = 0
        resetCurrentLesson()
        stage = .lesson
    }

    private func resetCurrentLesson() {
        boardState = TutorialBoardState(lesson: lesson)
        feedback = .idle
        hasSolvedCurrentLesson = false
        demoFrameIndex = 0
    }

    private func jumpToLesson(_ index: Int) {
        guard lessons.indices.contains(index) else { return }
        if index == lessonIndex {
            resetCurrentLesson()
            return
        }
        lessonIndex = index
    }

    private func markCompletedIfNeeded() {
        guard !hasMarkedCompleted else { return }
        hasMarkedCompleted = true
        onCompleted()
    }
}

private struct TutorialWelcomeView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Image(systemName: "checkerboard.rectangle")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("欢迎来到新手村")
                    .font(.system(size: 28, weight: .semibold))

                Text("用 10 个短关卡，边点棋盘边学会围棋最基础的规则。")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 360)
            }

            VStack(spacing: 12) {
                Button(action: onStart) {
                    Label("开始学习", systemImage: "play.fill")
                }
                .buttonStyle(CleanWhiteButtonStyle())

                Button(role: .cancel, action: onSkip) {
                    Text("跳过")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .font(.body.weight(.semibold))
            }
            .frame(maxWidth: 320)

            Spacer(minLength: 24)
        }
        .padding(24)
    }
}

private struct TutorialCompletionView: View {
    let onRestart: () -> Void
    let onStartGame: () -> Void
    let onOpenTsumego: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("入门完成")
                        .font(.system(size: 28, weight: .semibold))
                    Text("你已经掌握了落子、气、提子、禁手、劫、眼、死活和地盘的第一层直觉。")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: 460)

                VStack(spacing: 12) {
                    Button(action: onStartGame) {
                        Label("开始对局", systemImage: "person.2")
                    }

                    Button(action: onOpenTsumego) {
                        Label("去做死活题", systemImage: "scope")
                    }

                    Button(action: onRestart) {
                        Label("重新学习", systemImage: "arrow.counterclockwise")
                    }
                }
                .buttonStyle(CleanWhiteButtonStyle())
                .frame(maxWidth: 360)
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .padding(.top, 40)
        }
    }
}

private struct TutorialBoardView: View {
    let board: [[Stone]]
    let lastMove: Point?
    let highlightedPoints: [Point]
    let blackTerritory: [Point]
    let whiteTerritory: [Point]
    let hintPoint: Point?
    let successPoint: Point?
    let isInteractionEnabled: Bool
    let onTap: (Point) -> Void

    private var size: Int { board.count }

    var body: some View {
        GeometryReader { geo in
            let boardDimension = min(geo.size.width, geo.size.height)
            let cellSize = boardDimension / CGFloat(max(size, 1))
            let margin = cellSize / 2

            ZStack {
                Color(red: 0.85, green: 0.65, blue: 0.40)

                drawGrid(cellSize: cellSize, margin: margin)
                drawStarPoints(cellSize: cellSize, margin: margin)
                drawTerritory(cellSize: cellSize, margin: margin)
                drawPointMarkers(cellSize: cellSize, margin: margin)
                drawStones(cellSize: cellSize, margin: margin)
            }
            .frame(width: boardDimension, height: boardDimension)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.16), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                guard isInteractionEnabled else { return }
                let c = Int(round((location.x - margin) / cellSize))
                let r = Int(round((location.y - margin) / cellSize))
                let point = Point(r: r, c: c)
                guard point.isOnBoard(size: size) else { return }
                onTap(point)
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawGrid(cellSize: CGFloat, margin: CGFloat) -> some View {
        Path { path in
            let maxPos = margin + cellSize * CGFloat(size - 1)
            for i in 0..<size {
                let pos = margin + cellSize * CGFloat(i)
                path.move(to: CGPoint(x: margin, y: pos))
                path.addLine(to: CGPoint(x: maxPos, y: pos))
                path.move(to: CGPoint(x: pos, y: margin))
                path.addLine(to: CGPoint(x: pos, y: maxPos))
            }
        }
        .stroke(Color.black.opacity(0.62), lineWidth: 1)
    }

    private func drawStarPoints(cellSize: CGFloat, margin: CGFloat) -> some View {
        let points = [
            Point(r: 2, c: 2), Point(r: 2, c: 6),
            Point(r: 4, c: 4),
            Point(r: 6, c: 2), Point(r: 6, c: 6)
        ]

        return ForEach(points, id: \.self) { point in
            Circle()
                .fill(Color.black.opacity(0.62))
                .frame(width: cellSize * 0.18, height: cellSize * 0.18)
                .position(x: margin + CGFloat(point.c) * cellSize, y: margin + CGFloat(point.r) * cellSize)
        }
    }

    private func drawPointMarkers(cellSize: CGFloat, margin: CGFloat) -> some View {
        ZStack {
            ForEach(highlightedPoints, id: \.self) { point in
                marker(point: point, color: .blue, systemImage: "circle.fill", cellSize: cellSize, margin: margin)
            }

            if let hintPoint {
                marker(point: hintPoint, color: .orange, systemImage: "lightbulb.fill", cellSize: cellSize, margin: margin)
            }

            if let successPoint {
                marker(point: successPoint, color: .green, systemImage: "checkmark", cellSize: cellSize, margin: margin)
            }
        }
    }

    private func drawTerritory(cellSize: CGFloat, margin: CGFloat) -> some View {
        let markerSize = cellSize * 0.24

        return ZStack {
            ForEach(blackTerritory, id: \.self) { point in
                Rectangle()
                    .fill(Color.black.opacity(0.78))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.65), lineWidth: 0.7))
                    .frame(width: markerSize, height: markerSize)
                    .position(x: margin + CGFloat(point.c) * cellSize, y: margin + CGFloat(point.r) * cellSize)
            }

            ForEach(whiteTerritory, id: \.self) { point in
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .overlay(Rectangle().stroke(Color.black.opacity(0.45), lineWidth: 0.7))
                    .frame(width: markerSize, height: markerSize)
                    .position(x: margin + CGFloat(point.c) * cellSize, y: margin + CGFloat(point.r) * cellSize)
            }
        }
    }

    private func marker(point: Point, color: Color, systemImage: String, cellSize: CGFloat, margin: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.86))
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.4))
            Image(systemName: systemImage)
                .font(.system(size: cellSize * 0.24, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: cellSize * 0.56, height: cellSize * 0.56)
        .position(x: margin + CGFloat(point.c) * cellSize, y: margin + CGFloat(point.r) * cellSize)
        .shadow(color: color.opacity(0.26), radius: 3)
    }

    private func drawStones(cellSize: CGFloat, margin: CGFloat) -> some View {
        ForEach(0..<size, id: \.self) { r in
            ForEach(0..<size, id: \.self) { c in
                let stone = board[r][c]
                if stone != .empty {
                    ZStack {
                        Circle()
                            .fill(stone == .black ? Color.black : Color.white)
                            .shadow(color: .black.opacity(0.28), radius: 1.5, x: 1, y: 1)
                            .overlay(Circle().stroke(stone == .white ? Color.black.opacity(0.24) : Color.white.opacity(0.12), lineWidth: 0.8))

                        if lastMove == Point(r: r, c: c) {
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: cellSize * 0.44, height: cellSize * 0.44)
                        }
                    }
                    .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                    .position(x: margin + CGFloat(c) * cellSize, y: margin + CGFloat(r) * cellSize)
                }
            }
        }
    }
}

private enum TutorialFeedback: Equatable {
    case idle
    case wrong(String)
    case success(String)
}

private struct TutorialBoardState: Equatable {
    var board: [[Stone]]
    var currentPlayer: Stone
    var lastMove: Point?

    init(lesson: TutorialLesson, demoFrameIndex: Int = 0) {
        var board = Array(repeating: Array(repeating: Stone.empty, count: 9), count: 9)
        let stones = lesson.demoFrames.indices.contains(demoFrameIndex)
            ? lesson.demoFrames[demoFrameIndex].stones
            : lesson.initialStones

        for item in stones where item.point.isOnBoard(size: 9) {
            board[item.point.r][item.point.c] = item.stone
        }

        self.board = board
        self.currentPlayer = lesson.currentPlayer
        self.lastMove = lesson.demoFrames.indices.contains(demoFrameIndex)
            ? lesson.demoFrames[demoFrameIndex].lastMove
            : nil
    }

    @discardableResult
    mutating func place(_ point: Point) -> Bool {
        guard point.isOnBoard(size: board.count), board[point.r][point.c] == .empty else { return false }

        let previousBoard = board
        board[point.r][point.c] = currentPlayer

        for neighbor in neighbors(of: point) where board[neighbor.r][neighbor.c] == currentPlayer.opponent {
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
        currentPlayer = currentPlayer.next
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
}

#Preview {
    TutorialVillageView(
        isFirstLaunch: false,
        onSkip: {},
        onCompleted: {},
        onStartGame: {},
        onOpenTsumego: {}
    )
}
