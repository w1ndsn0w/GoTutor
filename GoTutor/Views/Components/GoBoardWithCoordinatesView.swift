import SwiftUI

struct GoBoardWithCoordinatesView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var game: GoGameViewModel
    @Binding var hoverPoint: Point?

    let showCoordinates: Bool
    let showStarPoints: Bool
    let showHoverGhost: Bool
    let showLastMoveMark: Bool
    let useWoodBackground: Bool
    let territory: TerritoryAnalysis?

    private let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"]

    var body: some View {
        GeometryReader { geo in
            let minDimension = min(geo.size.width, geo.size.height)
            let padding: CGFloat = showCoordinates ? 28 : 0
            let boardDimension = max( 0, minDimension - padding * 2)
            let cellSize = game.size > 0 ? (boardDimension / CGFloat(game.size)) : 0
                        let margin = cellSize / 2
                        let isAITurn = game.isAITurn

            ZStack {
                boardBackground
                if showCoordinates { drawCoordinates(boardDimension: boardDimension, cellSize: cellSize, padding: padding, margin: margin) }

                ZStack {
                    drawGrid(cellSize: cellSize, margin: margin)
                    if showStarPoints { drawStarPoints(cellSize: cellSize, margin: margin) }
                    drawStones(cellSize: cellSize, margin: margin)
                    drawTutorHint(cellSize: cellSize, margin: margin)
                    drawReviewHint(cellSize: cellSize, margin: margin)
                    drawCandidateMoves(cellSize: cellSize, margin: margin)
                    
                    if !game.isEndGameScoring && !isAITurn && showHoverGhost { drawHoverGhost(cellSize: cellSize, margin: margin) }
                    if let territory = territory { drawTerritory(territory: territory, cellSize: cellSize, margin: margin) }
                }
                .frame(width: boardDimension, height: boardDimension)
                .background(Color.white.opacity(0.001))
                // iPad 上悬停主要是给 Apple Pencil 用的
                .onContinuousHover { phase in handleHover(phase, margin: margin, cellSize: cellSize) }
                .onTapGesture(coordinateSpace: .local) { location in handleTap(location, margin: margin, cellSize: cellSize, isAITurn: isAITurn) }
            }
            .frame(width: minDimension, height: minDimension)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var boardBackground: some View {
        Group {
            if useWoodBackground {
                Color(red: 0.85, green: 0.65, blue: 0.40).shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                // 【适配 iPad】替换 NSColor
                Color(UIColor.secondarySystemBackground).shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.1), radius: 4, x: 0, y: 2)
            }
        }
    }

    private func drawHoverGhost(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if let hp = hoverPoint, hp.r >= 0 && hp.r < game.size && hp.c >= 0 && hp.c < game.size {
                if game.board[hp.r][hp.c] == .empty {
                    Circle()
                        .fill(game.currentPlayer == .black ? Color.black.opacity(0.4) : Color.white.opacity(0.5))
                        .frame(width: cellSize * 0.95, height: cellSize * 0.95)
                        .position(x: margin + CGFloat(hp.c) * cellSize, y: margin + CGFloat(hp.r) * cellSize)
                }
            }
        }
    }

    private func handleHover(_ phase: HoverPhase, margin: CGFloat, cellSize: CGFloat) {
        switch phase {
        case .active(let location):
            let c = Int(round((location.x - margin) / cellSize)); let r = Int(round((location.y - margin) / cellSize))
            if r >= 0 && r < game.size && c >= 0 && c < game.size { hoverPoint = Point(r: r, c: c) } else { hoverPoint = nil }
        case .ended: hoverPoint = nil
        }
    }

    private func handleTap(_ location: CGPoint, margin: CGFloat, cellSize: CGFloat, isAITurn: Bool) {
        let c = Int(round((location.x - margin) / cellSize)); let r = Int(round((location.y - margin) / cellSize))
        if game.isEndGameScoring { game.toggleDeadStone(atRow: r, col: c) }
        else if isAITurn { return }
        else { game.place(atRow: r, col: c) }
        hoverPoint = nil
    }

    private func drawGrid(cellSize: CGFloat, margin: CGFloat) -> some View {
        Path { path in
            let maxPos = margin + cellSize * CGFloat(game.size - 1)
            for i in 0..<game.size {
                let pos = margin + cellSize * CGFloat(i)
                path.move(to: CGPoint(x: margin, y: pos)); path.addLine(to: CGPoint(x: maxPos, y: pos))
                path.move(to: CGPoint(x: pos, y: margin)); path.addLine(to: CGPoint(x: pos, y: maxPos))
            }
        }.stroke(boardLineColor, lineWidth: 1)
    }

    private func drawStarPoints(cellSize: CGFloat, margin: CGFloat) -> some View {
        var starPoints: [Point] {
            switch game.size {
            case 19: return [Point(r: 3, c: 3), Point(r: 3, c: 9), Point(r: 3, c: 15), Point(r: 9, c: 3), Point(r: 9, c: 9), Point(r: 9, c: 15), Point(r: 15, c: 3), Point(r: 15, c: 9), Point(r: 15, c: 15)]
            case 13: return [Point(r: 3, c: 3), Point(r: 3, c: 9), Point(r: 9, c: 3), Point(r: 9, c: 9), Point(r: 6, c: 6)]
            case 9: return [Point(r: 2, c: 2), Point(r: 2, c: 6), Point(r: 6, c: 2), Point(r: 6, c: 6), Point(r: 4, c: 4)]
            default: return []
            }
        }
        return ForEach(starPoints, id: \.self) { pt in
            Circle().fill(boardLineColor.opacity(0.9)).frame(width: cellSize * 0.2, height: cellSize * 0.2)
                .position(x: margin + CGFloat(pt.c) * cellSize, y: margin + CGFloat(pt.r) * cellSize)
        }
    }

    private func drawStones(cellSize: CGFloat, margin: CGFloat) -> some View {
        ForEach(0..<game.size, id: \.self) { r in
            ForEach(0..<game.size, id: \.self) { c in
                let stone = game.board[r][c]
                if stone != .empty {
                    let isDead = game.deadStones.contains(Point(r: r, c: c))
                    ZStack {
                        Circle()
                            .fill(stone == .black ? Color.black : Color.white)
                            .shadow(color: .black.opacity(isDead ? 0.0 : 0.3), radius: 1.5, x: 1, y: 1)
                            .overlay(Circle().stroke(stone == .white ? Color.black.opacity(0.25) : Color.white.opacity(colorScheme == .dark ? 0.18 : 0), lineWidth: 0.7))
                            .opacity(isDead ? 0.3 : 1.0)
                        
                        if isDead { Image(systemName: "xmark").font(.system(size: cellSize * 0.6, weight: .heavy)).foregroundColor(.red.opacity(0.85)) }
                        if !isDead && showLastMoveMark, let lastMove = game.lastMove, case .place(let p) = lastMove.kind, p.r == r && p.c == c {
                            Circle().stroke(Color.red, lineWidth: 2).frame(width: cellSize * 0.45, height: cellSize * 0.45)
                        }
                    }
                    .frame(width: cellSize * 0.95, height: cellSize * 0.95)
                    .position(x: margin + CGFloat(c) * cellSize, y: margin + CGFloat(r) * cellSize)
                }
            }
        }
    }

    private func drawTutorHint(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if game.isTutorMode, let bestPt = game.previousBestMove {
                Circle().stroke(Color.blue, lineWidth: 3).frame(width: cellSize * 0.6, height: cellSize * 0.6).shadow(color: .blue.opacity(0.6), radius: 5)
                    .position(x: margin + CGFloat(bestPt.c) * cellSize, y: margin + CGFloat(bestPt.r) * cellSize)
            }
        }
    }
    private func drawReviewHint(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if game.isReviewMode, let bestPt = game.reviewBestMoveHint {
                Circle().stroke(Color.green, lineWidth: 3).frame(width: cellSize * 0.6, height: cellSize * 0.6).shadow(color: .green.opacity(0.6), radius: 5)
                    .position(x: margin + CGFloat(bestPt.c) * cellSize, y: margin + CGFloat(bestPt.r) * cellSize)
            }
        }
    }
    private func drawTerritory(territory: TerritoryAnalysis, cellSize: CGFloat, margin: CGFloat) -> some View {
        let markerSize = cellSize * 0.18
        return ZStack {
            ForEach(Array(territory.blackTerritory), id: \.self) { pt in
                Rectangle().fill(Color.black).frame(width: markerSize, height: markerSize)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 0.5))
                    .position(x: margin + CGFloat(pt.c) * cellSize, y: margin + CGFloat(pt.r) * cellSize)
            }
            ForEach(Array(territory.whiteTerritory), id: \.self) { pt in
                Rectangle().fill(Color.white).frame(width: markerSize, height: markerSize)
                    .overlay(Rectangle().stroke(Color.black.opacity(0.45), lineWidth: 0.5))
                    .position(x: margin + CGFloat(pt.c) * cellSize, y: margin + CGFloat(pt.r) * cellSize)
            }
        }
    }
    private func drawCoordinates(boardDimension: CGFloat, cellSize: CGFloat, padding: CGFloat, margin: CGFloat) -> some View {
        ZStack {
            ForEach(0..<game.size, id: \.self) { c in
                let x = padding + margin + CGFloat(c) * cellSize
                Text(letters[c]).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(coordinateColor).position(x: x, y: padding / 2)
                Text(letters[c]).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(coordinateColor).position(x: x, y: padding + boardDimension + padding / 2)
            }
            ForEach(0..<game.size, id: \.self) { r in
                let y = padding + margin + CGFloat(r) * cellSize
                let label = "\(game.size - r)"
                Text(label).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(coordinateColor).position(x: padding / 2, y: y)
                Text(label).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(coordinateColor).position(x: padding + boardDimension + padding / 2, y: y)
            }
        }
    }
    // ✅ 绘制数字 1、2、3 候选点
    private func drawCandidateMoves(cellSize: CGFloat, margin: CGFloat) -> some View {
        Group {
            if (game.isReviewMode || game.isTutorMode || game.shouldShowAICoachHints), let analysis = game.moveAnalyses[game.currentTurn] {
                ForEach(analysis.candidateMoves, id: \.order) { candidate in
                    // 动态将 "D4" 这种字符串翻译成屏幕坐标
                    if let pt = Point(gtp: candidate.move, boardSize: game.size),
                       game.board[pt.r][pt.c] == .empty { // 确保该位置没有被棋子挡住
                        
                        ZStack {
                            Circle()
                                .fill(colorForOrder(candidate.order).opacity(0.85))
                                .frame(width: cellSize * 0.55, height: cellSize * 0.55)
                                .shadow(radius: 2)
                            
                            Text("\(candidate.order)")
                                .font(.system(size: cellSize * 0.35, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .position(x: margin + CGFloat(pt.c) * cellSize, y: margin + CGFloat(pt.r) * cellSize)
                    }
                }
            }
        }
    }
    
    // 给不同名次的候选点不同的主色调 (1=蓝, 2=绿, 3=橙)
    private func colorForOrder(_ order: Int) -> Color {
        switch order {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        default: return .gray
        }
    }

    private var boardLineColor: Color {
        if useWoodBackground { return Color.black.opacity(0.62) }
        return colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.6)
    }

    private var coordinateColor: Color {
        if useWoodBackground { return Color.black.opacity(0.62) }
        return colorScheme == .dark ? Color.white.opacity(0.68) : Color.black.opacity(0.6)
    }
}
#Preview(){
    
}
