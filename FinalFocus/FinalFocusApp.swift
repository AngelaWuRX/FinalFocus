import SwiftUI

@main
struct FinalFocusApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task {
                    await model.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        model.failActiveCountdown(reason: "you left the app")
                    }
                }
        }
    }
}
