import SwiftUI
@main
struct PIDHunterApp: App {
    var body: some Scene {
        WindowGroup {
            //ContentView()
            SplashScreen()
                .environment(BikeProfileManager.shared)
        }
    }
}
