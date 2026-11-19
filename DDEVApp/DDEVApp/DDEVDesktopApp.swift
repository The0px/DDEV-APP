import DDEVKit
import SwiftUI

@main
struct DDEVDesktopApp: App {
    @State private var store = ProjectStore(client: DemoMode.isEnabled ? DemoMode.makeClient() : DDEVClient())

    var body: some Scene {
        WindowGroup("DDEV") {
            ContentView()
                .environment(store)
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 920, height: 560)
    }
}
