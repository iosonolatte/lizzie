import SwiftUI
import shared

struct BestMovesView: View {
    let bestMoves: [MoveData]
    let onMoveTap: (MoveData) -> Void

    var body: some View {
        if bestMoves.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Best Moves")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(bestMoves.prefix(5).enumerated()), id: \.offset) { index, move in
                            BestMoveChip(move: move, index: index + 1, onTap: { onMoveTap(move) })
                        }
                    }
                }
            }
        }
    }
}

struct BestMoveChip: View {
    let move: MoveData
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(move.coordinate)
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)
                Text(String(format: "%.1f%%", move.winrate * 100))
                    .font(.caption)
                Text("\(move.playouts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct WinrateGraphView: View {
    let history: BoardHistoryList
    let height: CGFloat

    var body: some View {
        // Simplified winrate graph placeholder
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: height)
            .overlay(
                Text("Winrate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }
}