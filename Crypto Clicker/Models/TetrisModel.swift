//
//  TetrisModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2025-01-07.
//

import Foundation
import SwiftUI

enum TetrisGameState {
    case notStarted, inProgress, paused, gameOver
}

// The tetris shapes
enum TetrominoType: CaseIterable {
    case I, O, T, S, Z, J, L
    
    // Block layouts in a 4x4 grid for the initial rotation state
    var shape: [[Int]] {
        switch self {
        case .I:
            return [
                [0,0,0,0],
                [1,1,1,1],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .O:
            return [
                [0,1,1,0],
                [0,1,1,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .T:
            return [
                [0,1,0,0],
                [1,1,1,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .S:
            return [
                [0,1,1,0],
                [1,1,0,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .Z:
            return [
                [1,1,0,0],
                [0,1,1,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .J:
            return [
                [1,0,0,0],
                [1,1,1,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        case .L:
            return [
                [0,0,1,0],
                [1,1,1,0],
                [0,0,0,0],
                [0,0,0,0]
            ]
        }
    }
}

struct TetrisPiece {
    
    var type: TetrominoType
    var shape: [[Int]]
    var row: Int
    var col: Int
    
    init(type: TetrominoType, row: Int, col: Int) {
        self.type = type
        self.shape = type.shape
        self.row = row
        self.col = col
    }
    
    // Rotate the piece clockwise
    mutating func rotate() {
        let n = shape.count
        var newShape = Array(repeating: Array(repeating: 0, count: n), count: n)
        // Perform matrix rotation
        for i in 0..<n {
            for j in 0..<n {
                newShape[j][n - i - 1] = shape[i][j]
            }
        }
        shape = newShape
    }
}

class TetrisModel: ObservableObject {
    
    @Published var gameState: TetrisGameState = .notStarted
    @Published var score: Int = 0
    @Published var topScore: Int = 0
    @Published var board: [[Int]]
    @Published var currentPiece: TetrisPiece?
    @Published var nextPiece: TetrisPiece?
    
    @Published var cachedMultiplier: Decimal = 1
    
    private var timer: Timer?
    private var fallInterval: TimeInterval = 3 // Initial fall speed (3 second per step)
    private let rows = 20
    private let columns = 12
    
    var cryptoStore: CryptoStore // Injected dependency
    
    init(cryptoStore: CryptoStore) {
        // Initialize an empty board with specified rows and columns
        self.cryptoStore = cryptoStore
        board = Array(repeating: Array(repeating: 0, count: columns), count: rows)
    }
    
    // Start a new game by resetting board, score, and game state
    func startGame() {
        
        Task { @MainActor in
            cachedMultiplier = cryptoStore.miniGameWinMultiplier > 0
            ? 1 + (cryptoStore.miniGameWinMultiplier / 100)
            : 1
        }
        resetBoard()
        score = 0
        fallInterval = 1.0
        gameState = .inProgress
        spawnNextPieces()
        startTimer()
    }
    
    // Pause or resume the game based on current state
    func pauseGame() {
        
        if gameState == .inProgress {
            gameState = .paused
            timer?.invalidate()
            
        } else if gameState == .paused {
            gameState = .inProgress
            startTimer()
        }
    }
    
    // End the game and invalidate the timer
    func endGame() {
        
        // Update top score
        if score > topScore {
            topScore = score
        }
        
        // Calculate the total reward using the score and multiplier
        let totalReward = Decimal(score) * cachedMultiplier
        
        // Safely update `cryptoStore` on the main thread
        DispatchQueue.main.async {
            self.cryptoStore.addCoinsFromMiniGame(totalReward)
        }
        
        gameState = .gameOver
        timer?.invalidate()
    }
    
    // Helper function to calculate the total bonus percentage
    @MainActor
    func getBonusPercentage() -> Int {
        
        let powerUpNames = ["5% Bonus Reward", "25% Bonus Reward", "100% Bonus Reward"]
        
        return powerUpNames.reduce(0) { total, name in
            
            if let powerUp = PowerUps.availablePowerUps.first(where: { $0.name == name }) {
                return total + (cryptoStore.powerUps.quantities[powerUp.name] ?? 0) * powerUp.coinsPerClickIncrease
            }
            return total
        }
    }
    
    // Reset the board and clear active pieces
    private func resetBoard() {
        board = Array(repeating: Array(repeating: 0, count: columns), count: rows)
        currentPiece = nil
        nextPiece = nil
    }
    
    // Start the game timer that triggers a game tick at the current fall interval
    private func startTimer() {
        timer?.invalidate() // Invalidate the previous timer
        timer = Timer.scheduledTimer(withTimeInterval: fallInterval, repeats: true) { _ in
            self.gameTick()
        }
    }
    
    // Called on each timer tick to move the piece down and update score
    private func gameTick() {
        guard gameState == .inProgress else { return }
        moveCurrentPieceDown()
        // Check if score threshold for speed increase is reached
        adjustFallSpeedIfNeeded()
    }
    
    // Check if the score threshold for faster falling is reached and adjust speed
    private func adjustFallSpeedIfNeeded() {
        
        let speedIncreaseThreshold = 300
        let speedIncreaseAmount: TimeInterval = 0.05 // Decrease fall interval by 0.05 seconds
        
        // Calculate the target fall speed based on the current score
        let newFallInterval = max(0.25, 3.0 - Double(score / speedIncreaseThreshold) * speedIncreaseAmount)
        
        // If the new interval is shorter than the current one, restart the timer
        if newFallInterval < fallInterval {
            fallInterval = newFallInterval
            startTimer()
        }
    }
    
    // Spawn a new current piece from nextPiece and prepare the following piece
    private func spawnNextPieces() {
        // Initialize nextPiece if it doesn't exist
        if nextPiece == nil {
            nextPiece = createRandomPiece()
        }
        // Set currentPiece to nextPiece and position it at the top
        currentPiece = nextPiece
        currentPiece?.row = 0
        currentPiece?.col = (columns - 4) / 2  // Center spawn (approx)
        nextPiece = createRandomPiece()
        
        // If the new piece cannot be placed, the board is full and the game ends
        if let piece = currentPiece, !isValidPosition(piece: piece) {
            endGame()
        }
    }
    
    // Create a random tetromino piece positioned at the top center
    private func createRandomPiece() -> TetrisPiece {
        let type = TetrominoType.allCases.randomElement()!
        return TetrisPiece(type: type, row: 0, col: (columns - 4) / 2)
    }
    
    // Check if a piece's position is valid (within bounds and not colliding)
    private func isValidPosition(piece: TetrisPiece) -> Bool {
        
        for r in 0..<piece.shape.count {
            
            for c in 0..<piece.shape[r].count {
                
                if piece.shape[r][c] != 0 {
                    
                    let newRow = piece.row + r
                    let newCol = piece.col + c
                    // Check boundaries
                    if newRow < 0 || newRow >= rows || newCol < 0 || newCol >= columns {
                        return false
                    }
                    // Check collision with settled blocks
                    if board[newRow][newCol] != 0 {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    // Rotate the current piece if possible
    func rotateCurrentPiece() {
        guard var piece = currentPiece else { return }
        piece.rotate()
        if isValidPosition(piece: piece) {
            currentPiece = piece
        }
    }
    
    // Move the current piece one step downwards until collision
    func fastDrop() {
        while let piece = currentPiece, canMoveDown(piece: piece) {
            moveCurrentPieceDown()
        }
    }
    
    // Move the current piece one row downwards
    private func moveCurrentPieceDown() {
        guard var piece = currentPiece else { return }
        piece.row += 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
        } else {
            // Cannot move further down: lock piece in place
            piece.row -= 1
            lockPiece(piece: piece)
            clearLines() // Check and clear any full lines after locking
            spawnNextPieces()
        }
    }
    
    // Check if the current piece can move downwards without collision
    private func canMoveDown(piece: TetrisPiece) -> Bool {
        var testPiece = piece
        testPiece.row += 1
        return isValidPosition(piece: testPiece)
    }
    
    // Lock the piece into the board state when it can no longer move down
    private func lockPiece(piece: TetrisPiece) {
        for r in 0..<piece.shape.count {
            for c in 0..<piece.shape[r].count {
                if piece.shape[r][c] != 0 {
                    let boardRow = piece.row + r
                    let boardCol = piece.col + c
                    if boardRow >= 0 && boardRow < rows && boardCol >= 0 && boardCol < columns {
                        board[boardRow][boardCol] = 1
                    }
                }
            }
        }
        // Increase score when a piece locks
        score += 10
    }
    
    // Attempt to move the current piece left if possible
    func moveCurrentPieceLeft() {
        guard var piece = currentPiece else { return }
        piece.col -= 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
        }
    }
    
    // Attempt to move the current piece right if possible
    func moveCurrentPieceRight() {
        guard var piece = currentPiece else { return }
        piece.col += 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
        }
    }
    
    // Clear complete lines from the board and update score
    private func clearLines() {
        // Iterate over rows to check for complete lines
        for row in (0..<rows).reversed() {
            if board[row].allSatisfy({ $0 != 0 }) {
                // Remove the full line
                board.remove(at: row)
                // Add an empty line at the top
                board.insert(Array(repeating: 0, count: columns), at: 0)
                // Increase score for clearing a line
                score += 100
            }
        }
    }
    
    private func calculateLandingPosition(for piece: TetrisPiece) -> Int {
        var testPiece = piece
        while isValidPosition(piece: testPiece) {
            testPiece.row += 1
        }
        return testPiece.row - 1 // The last valid position before collision
    }
    
    func getLandingPiece() -> TetrisPiece? {
        guard let piece = currentPiece else { return nil }
        var landingPiece = piece
        landingPiece.row = calculateLandingPosition(for: piece)
        return landingPiece
    }
    
    // Calculate the total reward
    func calculateReward() -> Decimal {
        let baseReward = Decimal(score)
        return baseReward * cachedMultiplier
    }
}
