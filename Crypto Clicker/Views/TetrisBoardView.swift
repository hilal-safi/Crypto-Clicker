//
//  TetrisBoardView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI

struct TetrisBoardView: View {
    let board: [[Int]] // The game board
    let currentPiece: TetrisPiece? // The currently active piece
    let landingPiece: TetrisPiece? // The preview of where the piece will land

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

    /// Determines the color for each cell based on the game state.
    private func colorForCell(row: Int, column: Int) -> Color {
        // Check if the cell is part of the landing piece (lighter color for preview).
        if let piece = landingPiece, isPieceCell(piece, row: row, column: column) {
            return piece.type.color.opacity(0.3)
        }

        // Check if the cell is part of the current active piece.
        if let piece = currentPiece, isPieceCell(piece, row: row, column: column) {
            return piece.type.color
        }

        // Check if the cell is part of a locked piece on the board.
        if board[row][column] != 0, let type = TetrominoType(rawValue: board[row][column]) {
            return type.color // Use TetrominoType's color
        }

        // Default cell background color (checkerboard pattern).
        return ((row + column) % 2 == 0) ? Color.gray.opacity(0.5) : Color.gray.opacity(0.7)
    }

    /// Helper to determine if a cell is part of a given piece.
    private func isPieceCell(_ piece: TetrisPiece, row: Int, column: Int) -> Bool {
        
        for r in 0..<piece.shape.count {
            
            for c in 0..<piece.shape[r].count {
                
                if piece.shape[r][c] != 0 && (piece.row + r == row) && (piece.col + c == column) {
                    return true
                }
            }
        }
        return false
    }
}

struct TetrisBoardView_Previews: PreviewProvider {
    
    static var previews: some View {
        // Sample board and pieces for preview
        let board = Array(repeating: Array(repeating: 0, count: 10), count: 20)
        let currentPiece = TetrisPiece(type: .T, row: 0, col: 3)
        let landingPiece = TetrisPiece(type: .T, row: 18, col: 3)

        return TetrisBoardView(board: board, currentPiece: currentPiece, landingPiece: landingPiece)
            .previewLayout(.fixed(width: 300, height: 600))
    }
}
