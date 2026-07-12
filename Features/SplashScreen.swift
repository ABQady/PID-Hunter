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
        let splashImageName = {
            #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone ? "PIDHunterSplash" : "PIDHunterSplashLandScape"
            #else
            "PIDHunterSplashLandScape"
            #endif
        }()
        if showApp {
            ContentView()
        } else {
            ZStack {
                Image(splashImageName)
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
