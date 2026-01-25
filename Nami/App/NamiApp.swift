import SwiftUI

@main
struct NamiApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView(appState: appState)
        } label: {
            Image(systemName: "waveform")
        }
        .menuBarExtraStyle(.window)
    }
}
