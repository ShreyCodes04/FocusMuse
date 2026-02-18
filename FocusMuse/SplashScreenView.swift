import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image("HourGlass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)

                Text("FocusMuse")
                    .font(.system(size: 36, weight: .bold))
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
