//
//  BlurView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-30.
//

import SwiftUI
import UIKit

struct BlurView: UIViewRepresentable {
    
    var style: UIBlurEffect.Style
    var reduction: CGFloat = 0.8 // Default reduction value (less blur)

    func makeUIView(context: Context) -> UIVisualEffectView {
        
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        
        view.alpha = reduction // Apply reduction to blur intensity
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.alpha = reduction // Ensure reduction updates dynamically
    }
}

struct BlurView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        ZStack {
            // Add a background for better visualization
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .foregroundColor(.yellow)

            // Add BlurView on top
            BlurView(style: .systemMaterialDark)
                .frame(width: 200, height: 200)
                .cornerRadius(12)
        }
        .previewLayout(.sizeThatFits)
    }
}
