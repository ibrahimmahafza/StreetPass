import PassbyCore
import SwiftUI

/// Keeps the app upright, except for a film shot with the phone on its side (`-filmwide`).
final class Orientation: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        ProcessInfo.processInfo.arguments.contains("-filmwide") ? .landscapeRight : .portrait
    }
}

@main
struct PassbyApp: App {
    @UIApplicationDelegateAdaptor(Orientation.self) private var orientation
    @State private var model = AppModel.live()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: phase, initial: true) { _, phase in
                    model.sceneChanged(active: phase == .active)
                }
                .onOpenURL { model.open($0) }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.demo == "gallery" {
            GalleryView()
        } else if model.demo == "hair" {
            HairGalleryView()
        } else if model.demo == "icon" {
            IconView()
        } else if model.state.me == nil {
            OnboardingView()
        } else {
            PlazaView().task { model.afterLaunch() }
        }
    }
}
