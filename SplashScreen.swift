//
//  SplashScreen
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//
import SwiftUI

struct SplashScreen: View {
    @State private var showApp = false
    var body: some View {
        if showApp {
            ContentView()
        } else {
            ZStack {
                Image("PIDHunterSplash")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            .task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 0.4)) {
                    showApp = true
                }
            }
        }
    }
}
