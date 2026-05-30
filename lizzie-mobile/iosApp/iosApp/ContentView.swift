import SwiftUI
import shared

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Lizzie Mobile")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.showSgfBrowser() }) {
                    Image(systemName: "folder")
                }
                Button(action: { viewModel.showSettings() }) {
                    Image(systemName: "gear")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // Board
            BoardView(
                boardData: viewModel.boardData,
                bestMoves: viewModel.bestMoves,
                showCoordinates: viewModel.showCoordinates,
                onIntersectionTap: { x, y in
                    viewModel.onIntersectionClick(x: x, y: y)
                }
            )
            .aspectRatio(1, contentMode: .fit)
            .padding(4)

            // Winrate graph
            WinrateGraphView(
                history: viewModel.history,
                height: 60
            )

            // Best moves
            BestMovesView(
                bestMoves: viewModel.bestMoves,
                onMoveTap: { move in
                    viewModel.onBestMoveTap(move: move)
                }
            )
            .padding(.horizontal)

            Spacer()
        }
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}