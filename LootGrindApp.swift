import SwiftUI

@main
struct LootGrindApp: App {
    @StateObject private var store = DealStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
