import AppKit
import ApplicationServices
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
        isMimicTyping: Bool,
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
                title: isMimicTyping ? "Stop Mimic" : "Mimic Type",
                systemImage: isMimicTyping ? "stop.fill" : "keyboard",
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

final class ActiveApplicationTracker {
    static let shared = ActiveApplicationTracker()

    private var observer: NSObjectProtocol?
    private var lastExternalApplication: NSRunningApplication?

    private init() {}

    func start() {
        guard observer == nil else { return }

        record(NSWorkspace.shared.frontmostApplication)

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application =
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            else {
                return
            }

            self?.record(application)
        }
    }

    var typingTargetApplication: NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
            isValidExternalApplication(frontmost)
        {
            return frontmost
        }

        return lastExternalApplication
    }

    private func record(_ application: NSRunningApplication?) {
        guard let application, isValidExternalApplication(application) else { return }
        lastExternalApplication = application
    }

    private func isValidExternalApplication(_ application: NSRunningApplication) -> Bool {
        application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && application.activationPolicy == .regular
            && !application.isTerminated
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

enum MimicTypeError: LocalizedError {
    case accessibilityPermissionRequired
    case emptyClipboard
    case noTargetApplication
    case pythonMissing
    case pynputMissing
    case scriptMissing
    case clipboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Grant Accessibility access to stealthx"
        case .emptyClipboard:
            return "Clipboard is empty"
        case .noTargetApplication:
            return "Activate the target app first"
        case .pythonMissing:
            return "Python 3 executable not found"
        case .pynputMissing:
            return "pynput is not installed for the selected Python"
        case .scriptMissing:
            return "Bundled mimic_type.py not found"
        case .clipboardWriteFailed:
            return "Could not write mimic input file"
        }
    }

    var statusText: String {
        switch self {
        case .accessibilityPermissionRequired:
            return "Enable Accessibility"
        case .emptyClipboard:
            return "Clipboard Empty"
        case .noTargetApplication:
            return "Activate Target App"
        case .pythonMissing:
            return "Python Missing"
        case .pynputMissing:
            return "Install pynput"
        case .scriptMissing, .clipboardWriteFailed:
            return "Mimic Failed"
        }
    }
}

@MainActor
final class MimicTypeController: ObservableObject {
    private static let startupDelaySeconds = "2.0"
    private static let inputDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".stealthx", isDirectory: true)
        .appendingPathComponent("tmp", isDirectory: true)
        .appendingPathComponent("txt", isDirectory: true)
    private static let inputFileURL = inputDirectory.appendingPathComponent("clip.txt")

    @Published private(set) var isRunning = false
    @Published var isVimModeEnabled = false

    private var process: Process?
    private var stopRequested = false
    private weak var hiddenOverlayWindow: NSWindow?
    private var hiddenOverlayWindowLevel: NSWindow.Level = .normal
    private var hiddenOverlayWindowWasVisible = false

    func toggleTyping(statusHandler: @escaping (String) -> Void) {
        if isRunning {
            stopTyping(statusHandler: statusHandler)
        } else {
            do {
                try startTyping(statusHandler: statusHandler)
            } catch let error as MimicTypeError {
                statusHandler(error.statusText)
            } catch {
                statusHandler("Mimic Failed")
            }
        }
    }

    private func startTyping(statusHandler: @escaping (String) -> Void) throws {
        guard process == nil else { return }

        try ensureAccessibilityAvailable()
        let inputFileURL = try prepareInputFile()
        let pythonURL = try pythonExecutableURL()
        try ensurePynputAvailable(using: pythonURL)
        let scriptURL = try scriptURL()

        guard let targetApplication = ActiveApplicationTracker.shared.typingTargetApplication else {
            throw MimicTypeError.noTargetApplication
        }

        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [
            scriptURL.path,
            "--file",
            inputFileURL.path,
            "--startup-delay",
            Self.startupDelaySeconds,
        ]
        process.standardError = errorPipe

        stopRequested = false
        hideOverlayWindowForTyping()

        process.terminationHandler = { [weak self] process in
            let errorOutput =
                String(
                    data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let owner = self

            Task { @MainActor in
                guard let owner else { return }

                owner.process = nil
                owner.isRunning = false
                owner.restoreOverlayWindowAfterTyping()

                if owner.stopRequested {
                    owner.stopRequested = false
                    statusHandler("Mimic Stopped")
                } else if process.terminationStatus == 0 {
                    statusHandler("Clipboard Typed")
                } else if errorOutput.isEmpty {
                    statusHandler("Mimic Failed")
                } else {
                    statusHandler("Mimic Failed")
                }
            }
        }

        targetApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        do {
            try process.run()
        } catch {
            restoreOverlayWindowAfterTyping()
            throw MimicTypeError.pythonMissing
        }

        self.process = process
        self.isRunning = true
        statusHandler("Typing Clipboard")
    }

    private func stopTyping(statusHandler: @escaping (String) -> Void) {
        guard let process, process.isRunning else {
            self.process = nil
            self.isRunning = false
            restoreOverlayWindowAfterTyping()
            statusHandler("Mimic Idle")
            return
        }

        stopRequested = true
        statusHandler("Stopping Mimic")
        process.terminate()
    }

    private func prepareInputFile() throws -> URL {
        guard
            let text = NSPasteboard.general.string(forType: .string)?
                .replacingOccurrences(of: "\r\n", with: "\n"),
            !text.isEmpty
        else {
            throw MimicTypeError.emptyClipboard
        }

        do {
            try FileManager.default.createDirectory(
                at: Self.inputDirectory,
                withIntermediateDirectories: true
            )
            try text.write(to: Self.inputFileURL, atomically: true, encoding: .utf8)
            return Self.inputFileURL
        } catch {
            throw MimicTypeError.clipboardWriteFailed
        }
    }

    private func scriptURL() throws -> URL {
        if let scriptURL = Bundle.main.url(forResource: "mimic_type", withExtension: "py") {
            return scriptURL
        }

        throw MimicTypeError.scriptMissing
    }

    private func pythonExecutableURL() throws -> URL {
        var firstExecutableURL: URL?

        for candidate in pythonCandidatePaths() where FileManager.default.isExecutableFile(atPath: candidate) {
            let candidateURL = URL(fileURLWithPath: candidate)
            if firstExecutableURL == nil {
                firstExecutableURL = candidateURL
            }

            if canImportPynput(using: candidateURL) {
                return candidateURL
            }
        }

        if let firstExecutableURL {
            return firstExecutableURL
        }

        throw MimicTypeError.pythonMissing
    }

    private func ensurePynputAvailable(using pythonURL: URL) throws {
        if !canImportPynput(using: pythonURL) {
            throw MimicTypeError.pynputMissing
        }
    }

    private func pythonCandidatePaths() -> [String] {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        return [
            "\(homePath)/.python-personal-packages/.persona-venv/bin/python3",
            "\(homePath)/.python-personal-packages/.persona-venv/bin/python3.14",
            "/opt/homebrew/opt/python@3.14/bin/python3.14",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
    }

    private func canImportPynput(using pythonURL: URL) -> Bool {
        let process = Process()
        process.executableURL = pythonURL
        process.arguments = ["-c", "import pynput"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        return process.terminationStatus == 0
    }

    private func ensureAccessibilityAvailable() throws {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary

        if !AXIsProcessTrustedWithOptions(options) {
            throw MimicTypeError.accessibilityPermissionRequired
        }
    }

    private func hideOverlayWindowForTyping() {
        guard let window = NSApp.windows.first(where: \.isVisible) else { return }

        hiddenOverlayWindow = window
        hiddenOverlayWindowLevel = window.level
        hiddenOverlayWindowWasVisible = window.isVisible
        window.orderOut(nil)
    }

    private func restoreOverlayWindowAfterTyping() {
        guard let window = hiddenOverlayWindow else { return }

        window.level = hiddenOverlayWindowLevel

        if hiddenOverlayWindowWasVisible {
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }

        hiddenOverlayWindow = nil
        hiddenOverlayWindowWasVisible = false
    }
}
