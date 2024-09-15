//
//  CoinView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

struct CoinView: View {
    
    let coin: CryptoCoin
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            Text("\(coin.value)")
                .font(.headline)
                .accessibilityAddTraits(/*@START_MENU_TOKEN@*/.isHeader/*@END_MENU_TOKEN@*/)
                
            .font(/*@START_MENU_TOKEN@*/.caption/*@END_MENU_TOKEN@*/)
        }
        .padding()
    }
    
}


struct CoinView_Previews: PreviewProvider {
    
    static var coin = CryptoCoin.sampleData
    
    static var previews: some View {
        CoinView(coin: coin)
            .previewLayout(.fixed(width: 400, height: 60))
    }
}
