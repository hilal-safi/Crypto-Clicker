//
//  AchievementsView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-27.
//

import SwiftUI

struct AchievementsView: View {
    var body: some View {
        VStack {
            Text("Achievements")
                .font(.largeTitle)
                .padding()

            Spacer()

            Text("Here you can view all your achievements!")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
}
