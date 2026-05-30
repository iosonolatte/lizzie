import SwiftUI
import shared

struct BoardView: View {
    let boardData: BoardData
    let bestMoves: [MoveData]
    let showCoordinates: Bool
    let onIntersectionTap: (Int32, Int32) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let marginFraction: CGFloat = showCoordinates ? 0.07 : 0.04
            let boardWidth: CGFloat = 19
            let squareSize = size / (boardWidth + marginFraction * 2)
            let margin = squareSize * marginFraction

            Canvas { context, canvasSize in
                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(Color(red: 0.86, green: 0.70, blue: 0.36))
                )

                // Grid lines
                for i in 0..<Int(boardWidth) {
                    let px = margin + CGFloat(i) * squareSize
                    // Vertical
                    var vPath = Path()
                    vPath.move(to: CGPoint(x: px, y: margin))
                    vPath.addLine(to: CGPoint(x: px, y: margin + (boardWidth - 1) * squareSize))
                    context.stroke(vPath, with: .color(.black), lineWidth: 1.5)

                    // Horizontal
                    var hPath = Path()
                    hPath.move(to: CGPoint(x: margin, y: px))
                    hPath.addLine(to: CGPoint(x: margin + (boardWidth - 1) * squareSize, y: px))
                    context.stroke(hPath, with: .color(.black), lineWidth: 1.5)
                }

                // Star points
                let starRadius = squareSize * 0.12
                // 19x19 star points
                let starPoints: [(Int, Int)] = [(3,3), (15,3), (9,3), (3,9), (15,9), (9,9), (3,15), (15,15), (9,15)]
                for (sx, sy) in starPoints {
                    let center = CGPoint(
                        x: margin + CGFloat(sx) * squareSize,
                        y: margin + CGFloat(sy) * squareSize
                    )
                    var starPath = Path()
                    starPath.addEllipse(in: CGRect(
                        x: center.x - starRadius,
                        y: center.y - starRadius,
                        width: starRadius * 2,
                        height: starRadius * 2
                    ))
                    context.fill(starPath, with: .color(.black))
                }

                // Stones
                let boardHelper = Board.companion
                for y in 0..<Int(boardWidth) {
                    for x in 0..<Int(boardWidth) {
                        let index = boardHelper.getIndex(x: Int32(x), y: Int32(y), width: Int32(boardWidth))
                        let stoneValue = boardData.stones.values[Int(index)]
                        guard stoneValue != Stone.empty.value else { continue }

                        let center = CGPoint(
                            x: margin + CGFloat(x) * squareSize,
                            y: margin + CGFloat(y) * squareSize
                        )
                        let stoneRadius = squareSize * 0.44

                        if stoneValue == Stone.black.value {
                            // Black stone with gradient
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: center.x - stoneRadius,
                                    y: center.y - stoneRadius,
                                    width: stoneRadius * 2,
                                    height: stoneRadius * 2
                                )),
                                with: .color(.black)
                            )
                        } else {
                            // White stone
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: center.x - stoneRadius,
                                    y: center.y - stoneRadius,
                                    width: stoneRadius * 2,
                                    height: stoneRadius * 2
                                )),
                                with: .color(.white)
                            )
                            // Border
                            context.stroke(
                                Path(ellipseIn: CGRect(
                                    x: center.x - stoneRadius,
                                    y: center.y - stoneRadius,
                                    width: stoneRadius * 2,
                                    height: stoneRadius * 2
                                )),
                                with: .color(.gray),
                                lineWidth: 1
                            )
                        }
                    }
                }

                // Last move marker
                if let lastMove = boardData.lastMove {
                    let lx = CGFloat(lastMove.first) * squareSize + margin
                    let ly = CGFloat(lastMove.second) * squareSize + margin
                    let markerRadius = squareSize * 0.15

                    let idx = boardHelper.getIndex(x: lastMove.first, y: lastMove.second, width: 19)
                    let stoneValue = boardData.stones.values[Int(idx)]
                    let markerColor: Color = stoneValue == Stone.black.value ? .white : .black

                    context.stroke(
                        Path(ellipseIn: CGRect(
                            x: lx - markerRadius,
                            y: ly - markerRadius,
                            width: markerRadius * 2,
                            height: markerRadius * 2
                        )),
                        with: .color(markerColor),
                        lineWidth: 2
                    )
                }
            }
            .gesture(
                TapGesture().onEnded {
                    // Tap location from the gesture
                }
            )
        }
    }
}

struct BoardView_Previews: PreviewProvider {
    static var previews: some View {
        let empty = BoardData.companion.empty(width: 19, height: 19)
        BoardView(
            boardData: empty,
            bestMoves: [],
            showCoordinates: true,
            onIntersectionTap: { _, _ in }
        )
    }
}