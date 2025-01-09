//
//  TetrisView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-07.
//

import SwiftUI

struct TetrisView: View {
    
    @EnvironmentObject var tetrisModel: TetrisModel
    @EnvironmentObject var cryptoStore: CryptoStore
    @State private var reward: Decimal = 0

    var body: some View {
        
        ZStack {
            // Base game UI
            BackgroundView(type: .minigames)
            
            VStack {
                // Top bar: Display top score, current score, and game state controls
                HStack {
                    Text("Top Score: \(tetrisModel.topScore)") // Display top score
                        .font(.headline)
                    Spacer()
                    Text("Score: \(tetrisModel.score)")
                        .font(.headline)
                    Spacer()
                    Button(action: { tetrisModel.pauseGame() }) {
                        Text(tetrisModel.gameState == .paused ? "Resume" : "Pause")
                    }
                }
                .padding([.leading, .trailing, .top], 8) // Reduced top bar padding

                // Main game board view
                TetrisBoardView(
                    board: tetrisModel.board,
                    currentPiece: tetrisModel.currentPiece,
                    landingPiece: tetrisModel.getLandingPiece() // Pass the landing piece
                )
                .aspectRatio(CGFloat(tetrisModel.board[0].count) / CGFloat(tetrisModel.board.count), contentMode: .fit)
                .padding(4)
                
                // Next piece preview
                if let next = tetrisModel.nextPiece {
                    VStack(spacing: 20) { // Use tighter spacing between "Next" label and piece
                        Text("Next:")
                            .font(.title3)
                            .bold()
                        TetrisPieceView(piece: next)
                            .frame(width: 50, height: 50) // Make the preview smaller and square
                    }
                }
                
                // Conditionally show control buttons only when game is in progress
                if tetrisModel.gameState == .inProgress {
                    HStack(spacing: 16) {
                        Button(action: {
                            tetrisModel.moveCurrentPieceLeft()
                        }) {
                            Text("←")
                                .font(.title)
                                .padding(8)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            tetrisModel.rotateCurrentPiece()
                        }) {
                            Text("Rotate")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            tetrisModel.fastDrop()
                        }) {
                            Text("Fast Drop")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            tetrisModel.moveCurrentPieceRight()
                        }) {
                            Text("→")
                                .font(.title)
                                .padding(8)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Start/Restart button
                if tetrisModel.gameState == .notStarted || tetrisModel.gameState == .gameOver {
                    Button(action: { tetrisModel.startGame() }) {
                        Text("Start Game")
                            .font(.title2)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(4) // Reduce overall padding of VStack

            // Overlay for Game Over screen
            if tetrisModel.gameState == .gameOver {
                
                VStack {
                    Text("Game Over")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                    Text("Your Score: \(tetrisModel.score)")
                        .font(.title2)
                        .padding()
                    Text("You earned \(reward) coins!")
                        .font(.headline)
                        .padding()
                    Button(action: {
                        tetrisModel.gameState = .notStarted
                    }) {
                        Text("Play Again")
                            .font(.title2)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .onAppear {
                    Task {
                        reward = tetrisModel.calculateReward()
                    }
                }
            }
        }
    }
}

struct TetrisBoardView: View {
    
    let board: [[Int]]
    let currentPiece: TetrisPiece?
    let landingPiece: TetrisPiece? // Add the landing piece

    var body: some View {
        
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width / CGFloat(board.first?.count ?? 10),
                               geometry.size.height / CGFloat(board.count))
            
            VStack(spacing: 0) {
                
                ForEach(0..<board.count, id: \.self) { row in
                    
                    HStack(spacing: 0) {
                        
                        ForEach(0..<board[row].count, id: \.self) { column in
                            
                            Rectangle()
                                .fill(colorForCell(row: row, column: column))
                                .frame(width: cellSize, height: cellSize)
                                .border(Color.gray, width: 1)
                        }
                    }
                }
            }
        }
    }

    func colorForCell(row: Int, column: Int) -> Color {
        // Check if the cell is part of the landing piece
        if let piece = landingPiece {
            
            for r in 0..<piece.shape.count {
                
                for c in 0..<piece.shape[r].count {
                    
                    if piece.shape[r][c] != 0 && (piece.row + r == row) && (piece.col + c == column) {
                        return Color.blue.opacity(0.3) // Semi-transparent blue
                    }
                }
            }
        }

        // Check if the cell is part of the current piece
        if let piece = currentPiece {
            
            for r in 0..<piece.shape.count {
                
                for c in 0..<piece.shape[r].count {
                    
                    if piece.shape[r][c] != 0 && (piece.row + r == row) && (piece.col + c == column) {
                        return .red
                    }
                }
            }
        }

        // Check if the cell is part of a settled block
        if board[row][column] != 0 {
            return .blue
        }

        // Empty cell with alternating colors for visibility
        return ((row + column) % 2 == 0) ? Color.gray.opacity(0.5) : Color.gray.opacity(0.7)
    }
}

struct TetrisPieceView: View {
    
    let piece: TetrisPiece
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            ForEach(0..<piece.shape.count, id: \.self) { row in
                
                HStack(spacing: 0) {
                    
                    ForEach(0..<piece.shape[row].count, id: \.self) { col in
                        
                        Rectangle()
                            .fill(piece.shape[row][col] != 0 ? Color.red : Color.clear)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
    }
}

struct TetrisView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        let model = TetrisModel(cryptoStore: store)
        
        return TetrisView()
            .environmentObject(model)
    }
}
