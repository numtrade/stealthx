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

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private weak var overlayWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ActiveApplicationTracker.shared.start()
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "MacUnixStatusIcon") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = false
                button.image = image
                button.title = ""
            } else {
                button.title = "SX"
            }

            button.toolTip = "stealthx"
            button.target = self
            button.action = #selector(toggleOverlayWindowFromStatusItem)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let window = NSApp.windows.first else { return }
            self.attachAndConfigureOverlayWindow(window)
            self.showOverlayWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showOverlayWindow()
        return false
    }

    @objc private func toggleOverlayWindowFromStatusItem() {
        guard let window = overlayWindow ?? NSApp.windows.first else { return }

        if overlayWindow == nil {
            attachAndConfigureOverlayWindow(window)
        }

        if window.isVisible {
            hideOverlayWindow()
        } else {
            showOverlayWindow()
        }
    }

    private func attachAndConfigureOverlayWindow(_ window: NSWindow) {
        overlayWindow = window
        window.delegate = self

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

        // Critical: keeps the overlay out of normal screenshots / screen sharing.
        window.sharingType = .none

        window.alphaValue = 1.0

        window.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .stationary,
            .ignoresCycle,
        ]

        window.level = .screenSaver
    }

    private func showOverlayWindow() {
        guard let window = overlayWindow ?? NSApp.windows.first else { return }

        if overlayWindow == nil {
            attachAndConfigureOverlayWindow(window)
        }

        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideOverlayWindow() {
        overlayWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == overlayWindow {
            hideOverlayWindow()
            return false
        }

        return true
    }
}
