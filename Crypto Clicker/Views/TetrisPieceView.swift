//
//  TetrisPieceView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-09.
//

import SwiftUI

struct TetrisPieceView: View {
    
    let piece: TetrisPiece
    let blockSize: CGFloat

    init(piece: TetrisPiece, blockSize: CGFloat = 25) {
        self.piece = piece
        self.blockSize = blockSize
    }

    var body: some View {
        
        GeometryReader { geometry in
            
            let gridSize = CGFloat(piece.shape.count)
            let scaledBlockSize = min(geometry.size.width, geometry.size.height) / gridSize

            VStack(spacing: 0) {
                
                ForEach(0..<piece.shape.count, id: \.self) { row in
                    
                    HStack(spacing: 0) {
                        
                        ForEach(0..<piece.shape[row].count, id: \.self) { column in
                            
                            if piece.shape[row][column] != 0 {
                                Rectangle()
                                    .fill(piece.type.color)
                                    .frame(width: scaledBlockSize, height: scaledBlockSize)
                            } else {
                                Spacer()
                                    .frame(width: scaledBlockSize, height: scaledBlockSize)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TetrisPieceView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let piece = TetrisPiece(type: .T, row: 0, col: 0)
        
        return TetrisPieceView(piece: piece)
            .frame(width: 120, height: 120)
            .border(Color.gray, width: 1)
            .padding()
    }
}
