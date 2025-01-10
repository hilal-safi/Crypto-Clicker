//
//  BlackjackMessageView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-23.
//

import SwiftUI

struct BlackjackMessageView: View {
    
    @EnvironmentObject var model: BlackjackModel
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode
    
    var body: some View {
        // Get the current message and its type
        let (text, type) = model.currentMessage()
        
        // Display the message with appropriate color
        
        ScrollView { // Allows scrolling for very long text
            
            Text(text)
                .font(.title3)
                .foregroundColor(getTextColor(for: type))
                .bold()
                .multilineTextAlignment(.center) // Aligns the text to the center
                .lineLimit(nil) // Allows the text to wrap onto multiple lines
                .frame(maxWidth: .infinity) // Ensures the text spans across the available width
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(getBackgroundColor()) // Dynamically set background color
                .opacity(0.7)
        )
    }
    
    /// Determines the text color based on the message type
    private func getTextColor(for type: MessageType) -> Color {
        
        switch type {
            
        case .win:
            return colorScheme == .dark ? Color(red: 0.0, green: 0.7, blue: 0.0) : Color(red: 0.0, green: 0.5, blue: 0.0)
        case .loss:
            return colorScheme == .dark ? Color(red: 0.8, green: 0.0, blue: 0.0) : Color(red: 0.6, green: 0.0, blue: 0.0)
        case .tie, .info:
            return colorScheme == .dark ? Color(red: 0.0, green: 0.4, blue: 0.8) : Color(red: 0.0, green: 0.3, blue: 0.6)
        }
    }
    
    /// Dynamically set background color based on the color scheme
    private func getBackgroundColor() -> Color {
        colorScheme == .dark
            ? Color(red: 0.2, green: 0.2, blue: 0.2) // Darker grey for dark mode
            : Color(red: 0.9, green: 0.9, blue: 0.9) // Lighter grey for light mode
    }
}

struct BlackjackMessageView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let exchangeModel = CoinExchangeModel.shared
        let cryptoStore = CryptoStore()
        let model = BlackjackModel(exchangeModel: exchangeModel, cryptoStore: cryptoStore)

        model.gameState = .waitingForBet
        
        return BlackjackMessageView()
            .environment(\.colorScheme, .light)
            .environmentObject(model)
    }
}
