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
            
            if board.isEmpty || board.first?.count ?? 0 == 0 {
                
                Text("Error: Board is not properly initialized")
                    .foregroundColor(.red)
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .accessibilityLabel("Error: Game board is not set correctly.")
                
            } else {
                
                let columns = board.first!.count
                let cellSize = min(geometry.size.width / CGFloat(columns),
                                   geometry.size.height / CGFloat(board.count))
                
                VStack(spacing: 0) {
                    
                    ForEach(0..<board.count, id: \.self) { row in
                        
                        HStack(spacing: 0) {
                            
                            ForEach(0..<columns, id: \.self) { column in
                                
                                Rectangle()
                                    .fill(colorForCell(row: row, column: column))
                                    .frame(width: cellSize, height: cellSize)
                                    .border(Color.gray, width: 1)
                                    .accessibilityLabel(accessibilityText(row: row, column: column))
                            }
                        }
                    }
                }
            }
        }
    }

    /// Determines the color for each cell based on the game state.
    private func colorForCell(row: Int, column: Int) -> Color {
        
        guard row >= 0, row < board.count, column >= 0, column < board[row].count else {
            return Color.clear
        }
        
        if let piece = landingPiece, isPieceCell(piece, row: row, column: column) {
            return piece.type.color.opacity(0.3)
        }
        
        if let piece = currentPiece, isPieceCell(piece, row: row, column: column) {
            return piece.type.color
        }
        
        if board[row][column] != 0, let type = TetrominoType(rawValue: board[row][column]) {
            return type.color
        }
        
        return ((row + column) % 2 == 0) ? Color.gray.opacity(0.4) : Color.gray.opacity(0.6)
    }

    /// Helper to determine if a cell is part of a given piece.
    private func isPieceCell(_ piece: TetrisPiece, row: Int, column: Int) -> Bool {
        
        for (r, rowArray) in piece.shape.enumerated() {
            
            for (c, value) in rowArray.enumerated() where value != 0 {
                
                if piece.row + r == row && piece.col + c == column {
                    return true
                }
            }
        }
        return false
    }
    
    /// Provides accessibility labels for VoiceOver users.
    private func accessibilityText(row: Int, column: Int) -> String {
        
        if let piece = currentPiece, isPieceCell(piece, row: row, column: column) {
            return "Active piece at row \(row), column \(column)"
            
        } else if let piece = landingPiece, isPieceCell(piece, row: row, column: column) {
            return "Landing preview at row \(row), column \(column)"
            
        } else if board[row][column] != 0 {
            return "Occupied cell at row \(row), column \(column)"
            
        } else {
            return "Empty cell at row \(row), column \(column)"
        }
    }
}

struct TetrisBoardView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let board = Array(repeating: Array(repeating: 0, count: 10), count: 20)
        let currentPiece = TetrisPiece(type: .T, row: 0, col: 3)
        let landingPiece = TetrisPiece(type: .T, row: 18, col: 3)
        
        return TetrisBoardView(board: board, currentPiece: currentPiece, landingPiece: landingPiece)
            .previewLayout(.fixed(width: 300, height: 600))
    }
}
