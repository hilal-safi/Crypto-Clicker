//
//  ErrorView.swift
//  Crypto Clicker Watch App
//
//  Created by Hilal Safi on 2025-01-15.
//

import SwiftUI

struct ErrorView: View {
    
    let errorWrapper: ErrorWrapper
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        VStack(spacing: 8) {
            
            Text("An error occurred")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(errorWrapper.error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
            
            Text(errorWrapper.guidance)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            
            Button("Dismiss") {
                dismiss()
            }
            .padding(.top, 8)
            .accessibilityLabel("Dismiss error view")
        }
        .padding()
        .background(Color(.gray).opacity(0.8))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
    }
}

struct ErrorView_Previews: PreviewProvider {
    enum SampleError: Error {
        case sample
    }
    
    static var previews: some View {
        ErrorView(
            errorWrapper: ErrorWrapper(
                error: SampleError.sample,
                guidance: "You can safely ignore this error."
            )
        )
    }
}
