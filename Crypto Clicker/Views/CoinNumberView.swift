//
//  CoinNumberView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct CoinNumberView: View {
    
    @Binding var coinValue: Decimal
    @Binding var showStatsPopup: Bool

    var body: some View {
        
        VStack(spacing: 10) {
            
            if coinValue == 0 {
                
                VStack(spacing: 5) {
                    
                    Text("Coin Value: 0")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.top, 9)
                        .accessibilityLabel("Coin value is zero") // VoiceOver

                    Text("Click the coin below to mine it and increase the value!")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true) // Ensures the text expands vertically
                        .padding(.horizontal, 16) // Provide enough padding for clarity
                        .padding(.bottom, 9)
                        .accessibilityLabel("Click the coin below to mine and increase its value") // VoiceOver hint
                }
                .background(BlurView(style: .systemMaterial, reduction: 0.8))
                .cornerRadius(12)
                .padding(8)
                .padding(.top, -8)
                .padding(.bottom, -22)
                
            } else {
                
                Button(action: {
                    showStatsPopup = true // Show stats popup when clicked
                    
                }) {
                    // Use the new `formattedCoinValue` extension method
                    Text(coinValue.formattedCoinValue())
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10) // Reduced padding
                        .padding(.vertical, 6)    // Reduced vertical padding
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
                        .accessibilityLabel("Current coin value: \(coinValue.formattedCoinValue())") // VoiceOver
                        .accessibilityHint("Tap to view statistics") // VoiceOver hint
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Preview
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
                coinValue: .constant(100_000_000), // Demonstrate formatting
                showStatsPopup: .constant(false)
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Non-Zero Coin Value")
        }
    }
}
