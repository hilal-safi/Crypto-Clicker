//
//  CoinNumberView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct CoinNumberView: View {
    
    @Binding var coinValue: Int
    @Binding var showStatsPopup: Bool

    var body: some View {
        
        VStack(spacing: 10) {
            
            if coinValue == 0 {
                
                VStack(spacing: 5) {
                    
                    Text("Coin Value: 0")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("Click the coin below to mine it and increase the value!")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            } else {
                
                Button(action: {
                    showStatsPopup = true // Show stats popup when clicked
                    
                }) {
                    Text("\(coinValue)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10) // Reduced padding
                        .padding(.vertical, 6) // Reduced vertical padding
                        .foregroundColor(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2)) // Subtle gray background
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Subtle border
                        )
                        .shadow(color: Color.gray.opacity(0.2), radius: 3, x: 0, y: 2) // Light shadow
                        .scaleEffect(showStatsPopup ? 1.05 : 1.0) // Small scale animation
                        .animation(.easeInOut(duration: 0.2), value: showStatsPopup)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct CoinNumberView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        Group {
            
            CoinNumberView(
                coinValue: .constant(0),
                showStatsPopup: .constant(false)
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Zero Coin Value")

            CoinNumberView(
                coinValue: .constant(100),
                showStatsPopup: .constant(false)
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Non-Zero Coin Value")
        }
    }
}
