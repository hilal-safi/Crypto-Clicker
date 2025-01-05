//
//  ContentView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-04.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var watchManager = WatchSessionManager.shared
    @StateObject var stepDetector = StepDetection() // Keep for step detection
    
    // Controls stats popup
    @State private var showStats = false
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            // The coin total text
            Text("\(watchManager.coinValue)")
                .font(.title3)
                .multilineTextAlignment(.center)
                .onTapGesture {
                    // Show stats popup
                    showStats = true
                }
                
            // The coin image as a button
            Button(action: {
                watchManager.tapCoin()
            }) {
                Image("coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(radius: 5)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Button to simulate steps
            Button("+100 Steps") {
                watchManager.addSteps(100)
            }
            
        }
        .sheet(isPresented: $showStats) {
            StatsView(
                isPresented: $showStats,
                steps: watchManager.totalSteps, // Use phone's totalSteps
                coinsFromSteps: watchManager.totalCoinsFromSteps // Use phone's totalCoinsFromSteps
            )
        }
        .onAppear {
            watchManager.startSession()
            watchManager.requestCoinData()
            
            // Optionally fetch steps immediately on first load
            // (The observer query will handle subsequent updates)
            stepDetector.fetchStepsSinceMidnight()
        }
        .onDisappear {
            stepDetector.saveData() // Save steps and coins before exiting
        }
    }
}

// MARK: - Updated StatsView
struct StatsView: View {
    @Binding var isPresented: Bool
    var steps: Int
    var coinsFromSteps: Decimal
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Stats")
                .font(.title2)
            
            // Display steps and coins gained from steps
            Text("Steps so far: \(steps)")
                .font(.headline)
            Text("Coins from steps: \(Double(truncating: coinsFromSteps as NSNumber), specifier: "%.0f")")
                .font(.headline)
            
            Button("Close") {
                isPresented = false
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .cornerRadius(8)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
            .previewDevice("Apple Watch Series 8 - 45mm")
            .previewDisplayName("Watch Preview")
    }
}
