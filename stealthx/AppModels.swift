import AppKit
import SwiftUI

// Backend integrations should only need to map behavior onto these typed actions
// instead of reaching into button declarations spread across the view.
enum OverlayAction: CaseIterable, Identifiable {
    case toggleTranscription
    case requestAnswer
    case copyTranscript
    case clearTranscript
    case captureScreenshot
    case mimicType
    case mirrorWindow

    static let primaryRow: [Self] = [
        .toggleTranscription,
        .requestAnswer,
        .copyTranscript,
        .clearTranscript,
    ]

    static let secondaryRow: [Self] = [
        .captureScreenshot,
        .mimicType,
    ]

    var id: Self { self }

    func presentation(
        isRecording: Bool,
        primaryWidth: CGFloat,
        secondaryWidth: CGFloat
    ) -> ActionButtonPresentation {
        switch self {
        case .toggleTranscription:
            return ActionButtonPresentation(
                title: isRecording ? "Stop" : "Start",
                systemImage: isRecording ? "stop.fill" : "waveform",
                width: primaryWidth
            )
        case .requestAnswer:
            return ActionButtonPresentation(
                title: "Answer",
                systemImage: "text.bubble.fill",
                width: primaryWidth
            )
        case .copyTranscript:
            return ActionButtonPresentation(
                title: "Copy",
                systemImage: "doc.on.doc",
                width: primaryWidth
            )
        case .clearTranscript:
            return ActionButtonPresentation(
                title: "Clear",
                systemImage: "xmark.circle",
                width: primaryWidth
            )
        case .captureScreenshot:
            return ActionButtonPresentation(
                title: "Screenshot",
                systemImage: "camera.viewfinder",
                width: secondaryWidth
            )
        case .mimicType:
            return ActionButtonPresentation(
                title: "Mimic Type",
                systemImage: "keyboard",
                width: secondaryWidth
            )
        case .mirrorWindow:
            return ActionButtonPresentation(
                title: "Mirror Window",
                systemImage: "rectangle.on.rectangle",
                width: secondaryWidth
            )
        }
    }
}

struct ActionButtonPresentation {
    let title: String
    let systemImage: String
    let width: CGFloat
}

struct MirrorExclusionApp: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let isCurrentApp: Bool
    let isAlwaysExcluded: Bool

    private init(
        id: String,
        name: String,
        bundleIdentifier: String?,
        icon: NSImage?,
        isCurrentApp: Bool,
        isAlwaysExcluded: Bool
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.isCurrentApp = isCurrentApp
        self.isAlwaysExcluded = isAlwaysExcluded
    }

    init(runningApplication: NSRunningApplication) {
        let bundleIdentifier = runningApplication.bundleIdentifier
        let processIdentifier = runningApplication.processIdentifier

        self.init(
            id: "\(bundleIdentifier ?? "pid"):\(processIdentifier)",
            name: runningApplication.localizedName ?? bundleIdentifier ?? "Unknown App",
            bundleIdentifier: bundleIdentifier,
            icon: runningApplication.icon,
            isCurrentApp: processIdentifier == ProcessInfo.processInfo.processIdentifier,
            isAlwaysExcluded: false
        )
    }

    static func currentOverlayApp() -> Self {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let processIdentifier = ProcessInfo.processInfo.processIdentifier
        let displayName =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName
        let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

        return Self(
            id: "\(bundleIdentifier ?? "current-app"):\(processIdentifier)",
            name: displayName,
            bundleIdentifier: bundleIdentifier,
            icon: appIcon,
            isCurrentApp: true,
            isAlwaysExcluded: true
        )
    }

    static func availableExclusions() -> [Self] {
        let currentApp = currentOverlayApp()

        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && application.localizedName != nil
                    && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
            .map(MirrorExclusionApp.init(runningApplication:))
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .reduce(into: [currentApp]) { result, app in
                if app.id != currentApp.id {
                    result.append(app)
                }
            }
    }
}
