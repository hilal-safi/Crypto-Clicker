//
//  PowerUpScrollView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-10.
//

import SwiftUI

struct PowerUpScrollView: View {
    
    @ObservedObject var store: CryptoStore // Observes changes in the store to reflect updates

    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 20) {
                
                ForEach(PowerUps.availablePowerUps, id: \.name) { powerUp in
                    
                    VStack {
                        
                        Text(powerUp.emoji)
                            .font(.system(size: 45))
                            .accessibilityLabel("\(powerUp.name) icon") // VoiceOver description
                        
                        // Since quantity(for:) returns an Int, no optional binding is needed.
                        let quantity = store.powerUps.quantity(for: powerUp.name)
                        
                        Text("\(quantity)")
                            .font(.system(size: 24, weight: .semibold))
                            .accessibilityLabel("\(quantity) \(powerUp.name) owned") // VoiceOver
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("Power-ups scrollable list") // VoiceOver hint
    }
}

struct PowerUpScrollView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockStore = CryptoStore()
        
        return PowerUpScrollView(store: mockStore)
            .frame(height: 100)
            .previewLayout(.sizeThatFits)
    }
}
