import SwiftUI

struct AchievementsView: View {
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
        }
        .navigationTitle("Achievements")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
