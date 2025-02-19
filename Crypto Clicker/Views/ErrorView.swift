//
//  ErrorView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-09-09.
//

import SwiftUI

struct ErrorView: View {
    
    let errorWrapper: ErrorWrapper
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        NavigationStack {
            
            VStack(spacing: 16) {
                
                // Display the error title
                Text(errorWrapper.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityLabel(errorWrapper.title)
                
                // Display the error description
                Text(errorWrapper.error.localizedDescription)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error description: \(errorWrapper.error.localizedDescription)")
                
                // Display error code if available
                if let code = errorWrapper.errorCode {
                    Text("Error Code: \(code)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Error Code \(code)")
                }
                
                // Display guidance message
                Text(errorWrapper.guidance)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                    .accessibilityLabel("Guidance: \(errorWrapper.guidance)")
                
                // Display the date/time of the error
                Text("Occurred on: \(errorWrapper.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Occurred on \(errorWrapper.date.formatted(date: .abbreviated, time: .shortened))")
                
                Spacer()
                
                // Action buttons: Dismiss and Report
                HStack(spacing: 20) {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibilityLabel("Dismiss error")
                    
                    Button("Report") {
                        // Integrate error reporting functionality here,
                        // such as sending errorWrapper.fullDescription() to your server.
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibilityLabel("Report error")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding()
            .accessibilityElement(children: .contain)
        }
    }
}

struct ErrorView_Previews: PreviewProvider {
    
    enum SampleError: Error {
        case errorRequired
    }
    
    static var wrapper: ErrorWrapper {
        ErrorWrapper(
            error: SampleError.errorRequired,
            guidance: "You can safely ignore this error.",
            title: "Critical Error",
            errorCode: 404
        )
    }
    
    static var previews: some View {
        ErrorView(errorWrapper: wrapper)
    }
}
