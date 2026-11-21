import PassbyCore
import SwiftUI

@main
struct PassbyApp: App {
    @State private var model = AppModel.live()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: phase, initial: true) { _, phase in
                    model.sceneChanged(active: phase == .active)
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.demo == "gallery" {
            GalleryView()
        } else if model.state.me == nil {
            OnboardingView()
        } else {
            PlazaView().task { model.afterLaunch() }
        }
    }
}
