import SwiftUI
import AppKit

private enum WindowMetrics {
    static let contentSize = NSSize(width: 420, height: 300)
}

@main
struct StealthxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()   
                .frame(
                    width: WindowMetrics.contentSize.width,
                    height: WindowMetrics.contentSize.height
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ActiveApplicationTracker.shared.start()
        NSApp.setActivationPolicy(.accessory)

        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            window.setContentSize(WindowMetrics.contentSize)
            window.contentMinSize = WindowMetrics.contentSize
            window.contentMaxSize = WindowMetrics.contentSize
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false
            window.canHide = false

            window.backgroundColor = NSColor.windowBackgroundColor
            window.isOpaque = true
            window.hasShadow = true
            window.sharingType = .none

            window.alphaValue = 1.0

            window.collectionBehavior = [
                .canJoinAllSpaces,
                .canJoinAllApplications,
                .stationary,
                .ignoresCycle,
            ]
            window.level = .screenSaver
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
