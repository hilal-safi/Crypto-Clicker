//
//  PowerButtonView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-08.
//

import SwiftUI

struct PowerButtonView: View {
    @ObservedObject var store: CryptoStore
    @State private var isPowerUpViewPresented = false  // Controls sheet presentation for PowerUpView

    var body: some View {
        Button(action: {
            isPowerUpViewPresented = true  // Open the sheet for PowerUpView
        }) {
            HStack(spacing: 20) {
                VStack {
                    Text("💻")
                        .font(.system(size: 42))  // Increased icon size
                    Text("\(store.chromebook)")
                        .font(.system(size: 24, weight: .semibold))  // Slightly larger quantity font
                }
                VStack {
                    Text("🖥️")
                        .font(.system(size: 42))  // Increased icon size
                    Text("\(store.desktop)")
                        .font(.system(size: 24, weight: .semibold))  // Slightly larger quantity font
                }
                VStack {
                    Text("🖲️")
                        .font(.system(size: 42))  // Increased icon size
                    Text("\(store.server)")
                        .font(.system(size: 24, weight: .semibold))  // Slightly larger quantity font
                }
                VStack {
                    Text("🏭")
                        .font(.system(size: 42))  // Increased icon size
                    Text("\(store.mineCenter)")
                        .font(.system(size: 24, weight: .semibold))  // Slightly larger quantity font
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))  // Light blue background tint
            .cornerRadius(12)  // Rounded corners
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)  // Outline for the button
            )
        }
        .sheet(isPresented: $isPowerUpViewPresented) {  // Present PowerUpView as a sheet
            PowerUpView(store: store)
        }
    }
}

struct PowerButtonView_Previews: PreviewProvider {
    static var previews: some View {
        let store = CryptoStore()
        store.chromebook = 1
        store.desktop = 2
        store.server = 3
        store.mineCenter = 4
        return PowerButtonView(store: store)
    }
}
