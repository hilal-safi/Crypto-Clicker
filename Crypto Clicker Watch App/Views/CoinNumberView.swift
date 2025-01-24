//
//  CoinNumberView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-15.
//

import SwiftUI

/// A view that displays the coin value (number) and can toggle StatsView.
struct CoinNumberView: View {
    
    @ObservedObject var watchManager: WatchSessionManager
    
    /// Controls whether the stats sheet is shown
    @Binding var showStats: Bool
    
    var body: some View {
        
        Text("\(watchManager.coinValue)")
            .font(.title3)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding(5)
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
            .shadow(color: .yellow, radius: 10)
            // Tapping the value opens the stats sheet
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showStats = true
                }
            }
            // **Accessibility**: Label the text as the current coin value
            .accessibilityLabel("Current coin value: \(watchManager.coinValue)")
    }
}

struct CoinNumberView_Previews: PreviewProvider {
    @State static var showStats = false
    
    static var previews: some View {
        CoinNumberView(watchManager: WatchSessionManager.shared, showStats: $showStats)
    }
}
