import SwiftUI

struct ContentView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            if isActive {
                MainTabView()
            } else {
                SplashScreenView()
            }
        }
        .onAppear {
            // Delay before transitioning
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

