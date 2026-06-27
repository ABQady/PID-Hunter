import SwiftUI
@main
struct PIDHunterApp: App {
    var body: some Scene {
        WindowGroup {
            //MyContentView()
            PIDHunterTabView()
        }
        .defaultSize(width: 650,height: 1000)
    }
}
