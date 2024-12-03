//
//  ExchangePopupView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-03.
//

import SwiftUI

struct ExchangePopupView: View {
    let message: String
    let isError: Bool

    var body: some View {
        VStack {
            Spacer()

            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(isError ? Color.red : Color.green)
                .cornerRadius(8)
                .padding(.horizontal, 20)

            Spacer()
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut, value: message)
    }
}

struct ExchangePopupView_Previews: PreviewProvider {
    static var previews: some View {
        ExchangePopupView(message: "Example Message", isError: false)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
