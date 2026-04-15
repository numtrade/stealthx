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

enum ScreenshotCaptureService {
    private static let executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    private static let outputDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".stealthx", isDirectory: true)
        .appendingPathComponent("tmp", isDirectory: true)
        .appendingPathComponent("screenshot", isDirectory: true)
    static let outputFileURL = outputDirectory.appendingPathComponent("screenshot.png")

    static func capture() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["-x", outputFileURL.path]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "ScreenshotCaptureService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorOutput]
            )
        }

        guard fileManager.fileExists(atPath: outputFileURL.path) else {
            throw NSError(
                domain: "ScreenshotCaptureService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "screencapture finished but did not create \(outputFileURL.path)"
                ]
            )
        }
    }

    @MainActor
    static func copyToClipboard() throws {
        guard let image = NSImage(contentsOf: outputFileURL) else {
            throw NSError(
                domain: "ScreenshotCaptureService",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not read screenshot at \(outputFileURL.path)"
                ]
            )
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.writeObjects([image]) else {
            throw NSError(
                domain: "ScreenshotCaptureService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not copy screenshot to clipboard"]
            )
        }
    }
}
