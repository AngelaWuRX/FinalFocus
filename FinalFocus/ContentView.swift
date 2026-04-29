import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.session.phase == .preparing || model.session.phase == .focusing {
                LockedCountdownView()
            } else {
                TabView {
                    DashboardView()
                        .tabItem { Label("Focus", systemImage: "timer") }

                    PlanView()
                        .tabItem { Label("Plan", systemImage: "checklist") }

                    RewardsView()
                        .tabItem { Label("Rewards", systemImage: "gift.fill") }
                }
                .tint(.mint)
            }
        }
        .preferredColorScheme(.dark)
    }
}
