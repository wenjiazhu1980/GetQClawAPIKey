import SwiftUI

@main
struct GetQClawApp: App {
    var body: some Scene {
        MenuBarExtra("QClaw", systemImage: "key.horizontal.fill") {
            ContentView()
                .frame(minWidth: 420, idealWidth: 480, maxWidth: 560,
                       minHeight: 400, maxHeight: 700)
        }
        .menuBarExtraStyle(.window)
    }
}