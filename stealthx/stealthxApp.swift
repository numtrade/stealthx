import SwiftUI
import AppKit

@main
struct StealthxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 420, height: 300)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = true

            window.backgroundColor = NSColor(
                calibratedRed: 0.72,
                green: 0.72,
                blue: 0.68,
                alpha: 1.0
            )
            window.isOpaque = true
            window.hasShadow = true

            window.alphaValue = 1.0

            window.level = .floating
        }
    }
}
