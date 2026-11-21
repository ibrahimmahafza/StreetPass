import PassbyCore
import SwiftUI

@main
struct PassbyApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.demo == "gallery" {
            GalleryView()
        } else if model.state.me == nil {
            Text("Passby")
        } else {
            PlazaView()
        }
    }
}
