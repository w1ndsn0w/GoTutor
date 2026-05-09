import SwiftUI
import Foundation

struct PurePlayBoardView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var game: GoGameViewModel

    let showStarPoints: Bool
    let showLastMoveMark: Bool
    let useWoodBackground: Bool

    @State private var hoverPoint: Point? = nil
    @State private var showResetAlert = false
    @State private var showGameOverAlert = false
    @State private var blackElapsedSeconds = 0
    @State private var whiteElapsedSeconds = 0

    private let timerPanelWidth: CGFloat = 112
    private let boardPadding: CGFloat = 12
    private let controlDockLongSide: CGFloat = 306

    var body: some View {
        GeometryReader { proxy in
            let usesSideTimers = usesSideTimerLayout(in: proxy.size)
            let usesStackedCompactControls = usesStackedCompactControlLayout(in: proxy.size)
            let boardSide = boardSide(in: proxy.size, usesSideTimers: usesSideTimers)

            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if usesSideTimers {
                    sideTimerBoardLayout(boardSide: boardSide)
                } else {
                    boardView(boardSide: boardSide)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    VStack(spacing: 0) {
                        compactPlayerStrip(for: .white, rotation: .degrees(180), stacksControls: usesStackedCompactControls)
                            .padding(.top, 14)
                        Spacer()

                        compactPlayerStrip(for: .black, stacksControls: usesStackedCompactControls)
                            .padding(.bottom, 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .statusBarHidden()
        .task {
            await runClock()
        }
        .onAppear {
            if game.isGameOver { showGameOverAlert = true }
        }
        .onChange(of: game.isGameOver) { _, isGameOver in
            if isGameOver { showGameOverAlert = true }
        }
        .alert("对局结束", isPresented: $showGameOverAlert) {
            Button("确定", role: .cancel) { }
            Button("重新开始") { resetGameAndTimers() }
        } message: {
            Text("连续两次 Pass。")
        }
        .alert("重新开始？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重新开始", role: .destructive) { resetGameAndTimers() }
        } message: {
            Text("当前棋局将被清空。")
        }
    }

    private func usesSideTimerLayout(in size: CGSize) -> Bool {
        let largestBoardSide = max(0, size.height - boardPadding * 2)
        let requiredWidth = largestBoardSide + timerPanelWidth * 2 + boardPadding * 4
        let requiredHeight = timerPanelWidth + controlDockLongSide + boardPadding * 3
        return size.width >= requiredWidth && size.height >= requiredHeight
    }

    private func usesStackedCompactControlLayout(in size: CGSize) -> Bool {
        size.width < 440
    }

    private func boardSide(in size: CGSize, usesSideTimers: Bool) -> CGFloat {
        if usesSideTimers {
            let widthLimitedSide = size.width - timerPanelWidth * 2 - boardPadding * 4
            return max(0, min(size.height - boardPadding * 2, widthLimitedSide))
        }

        let edgeReservedHeight: CGFloat = usesStackedCompactControlLayout(in: size) ? 150 : 84
        let heightLimitedSide = size.height - edgeReservedHeight * 2
        return max(0, min(size.width - boardPadding * 2, heightLimitedSide))
    }

    private func boardView(boardSide: CGFloat) -> some View {
        GoBoardWithCoordinatesView(
            game: game,
            hoverPoint: $hoverPoint,
            showCoordinates: false,
            showStarPoints: showStarPoints,
            showHoverGhost: false,
            showLastMoveMark: showLastMoveMark,
            useWoodBackground: useWoodBackground,
            territory: nil,
            showAnalysisOverlays: false
        )
        .frame(width: boardSide, height: boardSide)
    }

    private func sideTimerBoardLayout(boardSide: CGFloat) -> some View {
        HStack(spacing: boardPadding) {
            sidePlayerPanel(for: .black, rotation: .degrees(-90))

            boardView(boardSide: boardSide)

            sidePlayerPanel(for: .white, rotation: .degrees(90))
        }
        .padding(boardPadding)
    }

    private func compactPlayerStrip(for stone: Stone, rotation: Angle = .zero, stacksControls: Bool) -> some View {
        Group {
            if stacksControls {
                VStack(spacing: 8) {
                    timerCard(for: stone, isCompact: true)
                    horizontalControlDock()
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    timerCard(for: stone, isCompact: true)
                    Spacer(minLength: 12)
                    horizontalControlDock()
                }
            }
        }
        .padding(.horizontal, 14)
        .rotationEffect(rotation)
    }

    private func sidePlayerPanel(for stone: Stone, rotation: Angle) -> some View {
        VStack(spacing: boardPadding) {
            timerCard(for: stone, isCompact: false, rotation: rotation)
                .frame(width: timerPanelWidth, height: timerPanelWidth)
            Spacer(minLength: boardPadding)
            sideControlDock(rotation: rotation)
        }
        .frame(width: timerPanelWidth)
    }

    private func timerCard(for stone: Stone, isCompact: Bool, rotation: Angle = .zero) -> some View {
        PurePlayTimerCard(
            stone: stone,
            elapsedSeconds: stone == .black ? blackElapsedSeconds : whiteElapsedSeconds,
            isActive: game.currentPlayer == stone && !game.isGameOver,
            isCompact: isCompact
        )
        .rotationEffect(rotation)
    }

    private func horizontalControlDock() -> some View {
        HStack(spacing: 12) {
            controlItems
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func sideControlDock(rotation: Angle) -> some View {
        horizontalControlDock()
            .fixedSize()
            .rotationEffect(rotation)
            .frame(width: timerPanelWidth, height: controlDockLongSide)
    }

    @ViewBuilder
    private var controlItems: some View {
        currentPlayerMark
        undoButton
        passButton
        resetButton
        closeButton
    }

    private var currentPlayerMark: some View {
        Circle()
            .fill(game.currentPlayer == .black ? Color.black : Color.white)
            .overlay(Circle().stroke(Color.secondary.opacity(0.65), lineWidth: 1))
            .frame(width: 46, height: 46)
            .background(.regularMaterial, in: Circle())
            .accessibilityLabel(game.currentPlayer == .black ? "黑方落子" : "白方落子")
    }

    private var undoButton: some View {
        Button(action: { game.undo() }) {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(game.moves.isEmpty)
        .accessibilityLabel("悔棋")
        .buttonStyle(PurePlayIconButtonStyle())
    }

    private var passButton: some View {
        Button(action: { game.pass() }) {
            Image(systemName: "hand.raised")
        }
        .disabled(game.isGameOver || game.isAITurn)
        .accessibilityLabel("Pass")
        .buttonStyle(PurePlayIconButtonStyle())
    }

    private var resetButton: some View {
        Button(action: { showResetAlert = true }) {
            Image(systemName: "arrow.counterclockwise")
        }
        .accessibilityLabel("重新开始")
        .buttonStyle(PurePlayIconButtonStyle())
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("退出纯对弈")
        .buttonStyle(PurePlayIconButtonStyle())
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            tickClock()
        }
    }

    private func tickClock() {
        guard !game.isGameOver else { return }
        if game.currentPlayer == .black {
            blackElapsedSeconds += 1
        } else if game.currentPlayer == .white {
            whiteElapsedSeconds += 1
        }
    }

    private func resetGameAndTimers() {
        game.reset()
        blackElapsedSeconds = 0
        whiteElapsedSeconds = 0
    }
}

private struct PurePlayTimerCard: View {
    let stone: Stone
    let elapsedSeconds: Int
    let isActive: Bool
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 4 : 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(stone == .black ? Color.black : Color.white)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.7), lineWidth: 1))
                    .frame(width: 13, height: 13)

                Text(stone == .black ? "黑方" : "白方")
                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                    .lineLimit(1)
            }

            Text(formattedTime)
                .font(.system(size: isCompact ? 22 : 27, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, isCompact ? 12 : 10)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(width: isCompact ? 114 : 112)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.18), lineWidth: isActive ? 2 : 1)
        )
        .shadow(color: .black.opacity(isActive ? 0.16 : 0.06), radius: isActive ? 5 : 2, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stone == .black ? "黑方" : "白方")用时\(formattedTime)")
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct PurePlayIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
            .frame(width: 46, height: 46)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}
