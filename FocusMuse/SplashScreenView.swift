import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            
            // Dark Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // Sand Clock Icon
                Image(systemName: "hourglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.red)
                
                // App Name
                Text("FocusMuse")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
//
//  SplashScreenView.swift
//  FocusMuse
//
//  Created by Shreyan Sadhukhan on 12/02/26.
//

