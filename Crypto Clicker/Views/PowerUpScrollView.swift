//
//  PowerUpScrollView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-10.
//

import SwiftUI

struct PowerUpScrollView: View {
    
    let store: CryptoStore

    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 20) {
                
                ForEach(PowerUps.availablePowerUps, id: \.name) { powerUp in
                    
                    VStack {
                        Text(powerUp.emoji)
                            .font(.system(size: 45))
                        Text("\(store.powerUps.quantity(for: powerUp.name))")
                            .font(.system(size: 24, weight: .semibold))
                    }
                }
            }
            .padding(.horizontal)
        }
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
