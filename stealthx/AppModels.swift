import AppKit
import ApplicationServices
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit
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
        isMirrorRunning: Bool,
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
                title: isMirrorRunning ? "Stop Mirror" : "Create Mirror",
                systemImage: isMirrorRunning ? "stop.fill" : "rectangle.on.rectangle",
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

enum MirrorWindowError: LocalizedError {
    case invalidDisplayIndex
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDisplayIndex:
            return "Selected display is not available"
        case let .startFailed(message):
            return message
        }
    }

    var statusText: String {
        switch self {
        case .invalidDisplayIndex:
            return "Display Missing"
        case .startFailed:
            return "Mirror Failed"
        }
    }
}

struct MirrorCaptureSelection {
    let display: SCDisplay
    let excludedApplications: [SCRunningApplication]
    let missingBundleIDs: [String]
    let ownApplicationMatched: Bool
}

struct MirrorWindowHit {
    let pid: pid_t
    let bounds: CGRect
}

enum MirrorWindowSceneInspector {
    private static let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

    static func shouldHideCursor(at point: CGPoint, excludedProcessIDs: Set<pid_t>) -> Bool {
        guard let hit = topmostApplicationWindow(at: point) else {
            return false
        }

        return excludedProcessIDs.contains(hit.pid)
    }

    static func shouldFreezeFrame(displayFrame: CGRect, excludedProcessIDs: Set<pid_t>) -> Bool {
        guard let hit = topmostApplicationWindow(intersecting: displayFrame) else {
            return false
        }

        guard excludedProcessIDs.contains(hit.pid) else {
            return false
        }

        let intersection = hit.bounds.intersection(displayFrame)
        let coverage =
            (intersection.width * intersection.height)
            / max(displayFrame.width * displayFrame.height, 1)
        return coverage >= 0.85
    }

    private static func topmostApplicationWindow(at point: CGPoint) -> MirrorWindowHit? {
        windowInfos().lazy.compactMap(windowHit(from:)).first { $0.bounds.contains(point) }
    }

    private static func topmostApplicationWindow(intersecting displayFrame: CGRect) -> MirrorWindowHit? {
        windowInfos().lazy.compactMap(windowHit(from:)).first {
            !$0.bounds.intersection(displayFrame).isNull
        }
    }

    private static func windowInfos() -> [[String: Any]] {
        CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private static func windowHit(from info: [String: Any]) -> MirrorWindowHit? {
        guard
            let layer = info[kCGWindowLayer as String] as? NSNumber,
            layer.intValue == 0,
            let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
            let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        let alphaValue = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        guard alphaValue > 0.01, bounds.width > 1, bounds.height > 1 else {
            return nil
        }

        return MirrorWindowHit(pid: ownerPID.int32Value, bounds: bounds)
    }
}

func mirrorAspectFitRect(sourceSize: CGSize, destinationRect: CGRect) -> CGRect {
    guard
        sourceSize.width > 0,
        sourceSize.height > 0,
        destinationRect.width > 0,
        destinationRect.height > 0
    else {
        return destinationRect
    }

    let scale = min(
        destinationRect.width / sourceSize.width,
        destinationRect.height / sourceSize.height
    )
    let fittedSize = CGSize(
        width: sourceSize.width * scale,
        height: sourceSize.height * scale
    )
    let origin = CGPoint(
        x: destinationRect.minX + (destinationRect.width - fittedSize.width) / 2,
        y: destinationRect.minY + (destinationRect.height - fittedSize.height) / 2
    )

    return CGRect(origin: origin, size: fittedSize)
}

@MainActor
final class MirrorSurfaceView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present(_ image: CGImage) {
        layer?.contents = image
    }
}

@MainActor
final class MirrorViewController: NSViewController {
    private let surfaceView = MirrorSurfaceView(frame: .zero)
    private let cursorView = NSImageView(frame: .zero)
    private let displayFrame: CGRect
    private let excludedProcessIDs: Set<pid_t>
    private let shouldRenderCursor: Bool
    private let cursorHotSpot: NSPoint
    private var cursorTimer: Timer?

    init(
        displayFrame: CGRect,
        excludedProcessIDs: Set<pid_t>,
        shouldRenderCursor: Bool
    ) {
        self.displayFrame = displayFrame
        self.excludedProcessIDs = excludedProcessIDs
        self.shouldRenderCursor = shouldRenderCursor
        self.cursorHotSpot = NSCursor.arrow.hotSpot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 820))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        cursorView.image = NSCursor.arrow.image
        cursorView.imageScaling = .scaleNone
        cursorView.isHidden = true
        cursorView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.addSubview(cursorView)

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surfaceView)

        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if shouldRenderCursor {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateCursorOverlay()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            cursorTimer = timer
        }
    }

    deinit {
        cursorTimer?.invalidate()
    }

    func present(_ image: CGImage) {
        surfaceView.present(image)
        updateCursorOverlay()
    }

    private func updateCursorOverlay() {
        guard shouldRenderCursor else {
            cursorView.isHidden = true
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard displayFrame.contains(mouseLocation) else {
            cursorView.isHidden = true
            return
        }

        if MirrorWindowSceneInspector.shouldHideCursor(at: mouseLocation, excludedProcessIDs: excludedProcessIDs) {
            cursorView.isHidden = true
            return
        }

        guard let image = cursorView.image else {
            cursorView.isHidden = true
            return
        }

        let fittedRect = mirrorAspectFitRect(
            sourceSize: displayFrame.size,
            destinationRect: surfaceView.bounds
        )
        let relativeX = (mouseLocation.x - displayFrame.minX) / displayFrame.width
        let relativeY = (mouseLocation.y - displayFrame.minY) / displayFrame.height
        let origin = CGPoint(
            x: fittedRect.minX + (relativeX * fittedRect.width) - cursorHotSpot.x,
            y: fittedRect.minY + (relativeY * fittedRect.height) - cursorHotSpot.y
        )

        cursorView.frame = CGRect(origin: origin, size: image.size)
        cursorView.isHidden = false
    }
}

final class MirrorStreamOutput: NSObject, SCStreamOutput {
    let outputQueue = DispatchQueue(label: "stealthx.mirror.output")

    private let ciContext = CIContext()
    private weak var controller: MirrorViewController?
    private let displayFrame: CGRect
    private let excludedProcessIDs: Set<pid_t>
    private let stateQueue = DispatchQueue(label: "stealthx.mirror.output.state")
    private var isStopping = false

    init(controller: MirrorViewController, displayFrame: CGRect, excludedProcessIDs: Set<pid_t>) {
        self.controller = controller
        self.displayFrame = displayFrame
        self.excludedProcessIDs = excludedProcessIDs
    }

    func beginStopping() {
        stateQueue.sync {
            isStopping = true
        }
    }

    private func stopping() -> Bool {
        stateQueue.sync { isStopping }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        guard !stopping() else { return }
        guard CMSampleBufferIsValid(sampleBuffer) else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard
            !MirrorWindowSceneInspector.shouldFreezeFrame(
                displayFrame: displayFrame,
                excludedProcessIDs: excludedProcessIDs
            )
        else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        Task { @MainActor [weak self] in
            self?.controller?.present(cgImage)
        }
    }
}

@MainActor
final class MirrorWindowController: NSObject, ObservableObject, NSWindowDelegate, SCStreamDelegate {
    private let displayIndex = 0
    private let fps = 12
    private let showCursor = true

    @Published private(set) var isRunning = false

    private var stream: SCStream?
    private var output: MirrorStreamOutput?
    private var window: NSWindow?
    private var shutdownTask: Task<Void, Never>?
    private var isStopping = false
    private let stopQueue = DispatchQueue(label: "stealthx.mirror.stop")

    func createOrUpdateMirror(
        excludingBundleIDs: [String],
        statusHandler: @escaping (String) -> Void
    ) {
        statusHandler("Launching Mirror")

        Task { @MainActor in
            do {
                try await start(excludingBundleIDs: excludingBundleIDs)
                statusHandler("Mirror Running")
            } catch let error as MirrorWindowError {
                statusHandler(error.statusText)
            } catch {
                statusHandler("Mirror Failed")
            }
        }
    }

    func stopMirror(statusHandler: @escaping (String) -> Void) {
        guard !isStopping else { return }
        statusHandler("Stopping Mirror")

        guard let stream else {
            isRunning = false
            finishMirrorShutdown(statusHandler: statusHandler, finalStatus: "Mirror Stopped")
            return
        }

        isStopping = true
        output?.beginStopping()
        isRunning = false
        window?.orderOut(nil)

        let streamToStop = stream

        shutdownTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await self.stopStream(streamToStop)

                await MainActor.run {
                    self.finishMirrorShutdown(
                        statusHandler: statusHandler,
                        finalStatus: "Mirror Stopped"
                    )
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.finishMirrorShutdown(
                        statusHandler: statusHandler,
                        finalStatus: "Mirror Failed"
                    )
                }
            }
        }
    }

    private func start(excludingBundleIDs: [String]) async throws {
        if let shutdownTask {
            await shutdownTask.value
            self.shutdownTask = nil
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let selection = try resolveCaptureSelection(
            content: content,
            excludingBundleIDs: excludingBundleIDs
        )
        let excludedProcessIDs = Set(selection.excludedApplications.map(\.processID))
        let controller = MirrorViewController(
            displayFrame: selection.display.frame,
            excludedProcessIDs: excludedProcessIDs,
            shouldRenderCursor: showCursor
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Presentation Display"
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        window.tabbingMode = .disallowed
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.contentViewController = controller
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        self.window = window

        let filter = SCContentFilter(
            display: selection.display,
            excludingApplications: selection.excludedApplications,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.width = selection.display.width
        configuration.height = selection.display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        configuration.showsCursor = showCursor
        configuration.queueDepth = 2

        let output = MirrorStreamOutput(
            controller: controller,
            displayFrame: selection.display.frame,
            excludedProcessIDs: excludedProcessIDs
        )
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        self.output = output
        self.stream = stream

        try stream.addStreamOutput(
            output,
            type: .screen,
            sampleHandlerQueue: output.outputQueue
        )

        try await stream.startCapture()
        NSApp.activate(ignoringOtherApps: true)
        isRunning = true

        if !selection.ownApplicationMatched {
            fputs(
                "[mirror] warning: could not match stealthx in ScreenCaptureKit content\n",
                stderr
            )
        }
    }

    private func resolveCaptureSelection(
        content: SCShareableContent,
        excludingBundleIDs: [String]
    ) throws -> MirrorCaptureSelection {
        guard displayIndex >= 0, displayIndex < content.displays.count else {
            throw MirrorWindowError.invalidDisplayIndex
        }

        let display = content.displays[displayIndex]
        let requestedBundleIDs = Set(excludingBundleIDs)
        var excludedApplications = content.applications.filter {
            requestedBundleIDs.contains($0.bundleIdentifier)
        }
        let missingBundleIDs = requestedBundleIDs.subtracting(
            Set(excludedApplications.map(\.bundleIdentifier))
        ).sorted()

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let ownApplication = content.applications.first { $0.processID == currentPID }
        let ownApplicationMatched = ownApplication != nil
        if let ownApplication {
            excludedApplications.append(ownApplication)
        }

        return MirrorCaptureSelection(
            display: display,
            excludedApplications: uniqueApplications(excludedApplications),
            missingBundleIDs: missingBundleIDs,
            ownApplicationMatched: ownApplicationMatched
        )
    }

    private func uniqueApplications(_ applications: [SCRunningApplication]) -> [SCRunningApplication] {
        var seen = Set<pid_t>()
        var unique: [SCRunningApplication] = []

        for application in applications where !seen.contains(application.processID) {
            seen.insert(application.processID)
            unique.append(application)
        }

        return unique
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        fputs("[mirror] capture stream stopped: \(error)\n", stderr)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isRunning && !isStopping {
            stopMirror { _ in }
            return false
        }

        return !isStopping
    }

    private func stopStream(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stopQueue.async {
                stream.stopCapture { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    private func finishMirrorShutdown(
        statusHandler: @escaping (String) -> Void,
        finalStatus: String
    ) {
        shutdownTask = nil
        isStopping = false

        output = nil
        stream = nil

        if let window {
            window.delegate = nil
            window.close()
        }
        window = nil

        statusHandler(finalStatus)
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
    private static let startupDelaySeconds: TimeInterval = 2.0
    private static let overlayReturnDelaySeconds: TimeInterval = 2.25
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
    private var overlayWasShownDuringTyping = false
    private var overlayRestoreTask: Task<Void, Never>?

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
        var arguments = [
            scriptURL.path,
            "--file",
            inputFileURL.path,
            "--startup-delay",
            String(Self.startupDelaySeconds),
        ]
        if isVimModeEnabled {
            arguments.append("--vim")
        }
        process.arguments = arguments
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
        scheduleOverlayWindowReturn()
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
        overlayRestoreTask?.cancel()
        overlayRestoreTask = nil

        guard let window = NSApp.windows.first(where: \.isVisible) else { return }

        hiddenOverlayWindow = window
        hiddenOverlayWindowLevel = window.level
        hiddenOverlayWindowWasVisible = window.isVisible
        overlayWasShownDuringTyping = false
        window.orderOut(nil)
    }

    private func restoreOverlayWindowAfterTyping() {
        overlayRestoreTask?.cancel()
        overlayRestoreTask = nil

        guard let window = hiddenOverlayWindow else { return }

        if hiddenOverlayWindowWasVisible && !overlayWasShownDuringTyping {
            window.level = hiddenOverlayWindowLevel
            window.orderFrontRegardless()
        }

        hiddenOverlayWindow = nil
        hiddenOverlayWindowWasVisible = false
        overlayWasShownDuringTyping = false
    }

    private func scheduleOverlayWindowReturn() {
        guard hiddenOverlayWindowWasVisible else { return }

        overlayRestoreTask = Task { @MainActor [weak self] in
            let delayNanoseconds =
                UInt64(Self.overlayReturnDelaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            guard let self, self.process?.isRunning == true else { return }
            self.showOverlayWindowDuringTyping()
        }
    }

    private func showOverlayWindowDuringTyping() {
        guard let window = hiddenOverlayWindow else { return }

        window.level = hiddenOverlayWindowLevel
        window.orderFrontRegardless()
        overlayWasShownDuringTyping = true
    }
}
