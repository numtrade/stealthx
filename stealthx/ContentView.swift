import SwiftUI
import AppKit

private enum ContentMode {
    case transcript
    case mirrorSetup
}

struct ContentView: View {
    var showsWindowBounds = false

    @StateObject private var mimicTypeController = MimicTypeController()
    @StateObject private var mirrorWindowController = MirrorWindowController()
    @State private var transcript = ""
    @State private var isRecording = false
    @State private var status = "Ready"
    @State private var transcriptTask: Task<Void, Never>?
    @State private var contentMode: ContentMode = .transcript
    @State private var mirrorExclusionApps: [MirrorExclusionApp] = []
    @State private var excludedMirrorAppIDs: Set<String> = []

    private let transcriptPlaceholder =
        "Speaker transcript appears here after Start begins speaker-output capture."
    private let actionButtonWidth: CGFloat = 92
    private let secondaryActionButtonWidth: CGFloat = 126
    private let headerActionButtonWidth: CGFloat = 142
    private let primaryActions = OverlayAction.primaryRow
    // Mock speaker-side transcript until backend wires live system-audio transcription.
    private let mockSpeakerTranscriptParagraphs = [
        "Starting speaker-output transcription demo so the backend team can see the intended flow clearly.",
        "This transcript is still hard-coded for the handoff, but it now appears word by word like live text coming from the speaker output.",
        "Replace this mocked stream with real speaker-output transcription events once the backend is ready.",
        "Auto-follow should remain smooth as the transcript grows, and it should stop pulling the view when someone scrolls up to review older words.",
    ]

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                headerView

                if isShowingMirrorSetup {
                    mirrorSetupView
                } else {
                    transcriptPanel

                    ActionButtonRow(
                        actions: primaryActions,
                        presentation: actionPresentation(for:),
                        perform: perform
                    )

                    secondaryActionRow
                }
            }
            .padding(14)
        }
        .overlay {
            if showsWindowBounds {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        Color.cyan.opacity(0.8),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            }
        }
    }

    private var primaryTextColor: Color {
        Color(nsColor: .labelColor)
    }

    private var secondaryTextColor: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    private var panelStroke: Color {
        primaryTextColor.opacity(0.08)
    }

    private var transcriptBackgroundColor: Color {
        Color(nsColor: .textBackgroundColor).opacity(0.9)
    }

    private var indicatorColor: Color {
        isRecording ? Color(nsColor: .systemRed) : Color.gray.opacity(0.5)
    }

    private var headerView: some View {
        Group {
            if isShowingMirrorSetup {
                mirrorSetupHeaderView
            } else {
                transcriptHeaderView
            }
        }
    }

    private var quitButton: some View {
        Button(role: .destructive) {
            quitApplication()
        } label: {
            Label("Quit", systemImage: "power")
                .font(.system(size: 12, weight: .regular))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var transcriptHeaderView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            Text("MacUnix")
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            Spacer()

            ActionButton(
                presentation: headerActionPresentation(for: .mirrorWindow),
                perform: { perform(.mirrorWindow) },
                controlSize: .small
            )
            .layoutPriority(1)

            quitButton

            Text(status)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var mirrorSetupHeaderView: some View {
        HStack(spacing: 8) {
            Button {
                dismissMirrorWindowSetup()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Mirror Window")
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            Spacer()

            quitButton

            Text("Exclude Apps")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
        }
    }

    private var transcriptPanel: some View {
        ZStack(alignment: .topLeading) {
            TranscriptTextView(text: transcript)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if transcript.isEmpty {
                Text(transcriptPlaceholder)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(transcriptTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(transcriptBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(panelStroke, lineWidth: 1)
        )
    }

    private var secondaryActionRow: some View {
        HStack(spacing: 8) {
            ActionButton(
                presentation: actionPresentation(for: .captureScreenshot),
                perform: { perform(.captureScreenshot) }
            )

            HStack(spacing: 10) {
                ActionButton(
                    presentation: actionPresentation(for: .mimicType),
                    perform: { perform(.mimicType) }
                )

                Toggle("Vim", isOn: $mimicTypeController.isVimModeEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(primaryTextColor)
                    .disabled(mimicTypeController.isRunning)
                    .help("Reserve this for Vim-specific mimic typing behavior.")
            }

            Spacer(minLength: 0)
        }
    }

    private var isShowingMirrorSetup: Bool {
        contentMode == .mirrorSetup
    }

    private var mirrorSetupView: some View {
        VStack(spacing: 12) {
            mirrorSetupPanel

            HStack(spacing: 8) {
                Button("Refresh Apps") {
                    refreshMirrorExclusionApps()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text(mirrorSelectionSummary)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                Button(mirrorSetupButtonTitle) {
                    toggleMirrorFromSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var mirrorSetupPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose which running apps should stay out of the mirrored screen.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(primaryTextColor)

            Text("This is a GUI-only handoff for backend wiring. The selection stays inside the app for now, and this overlay app remains excluded by default.")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)

            Group {
                if mirrorExclusionApps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No running apps found.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(primaryTextColor)

                        Text("Refresh the list once the apps you want to exclude are open.")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(mirrorExclusionApps) { app in
                                MirrorExclusionAppRow(
                                    app: app,
                                    isSelected: excludedMirrorAppIDs.contains(app.id),
                                    toggle: { toggleMirrorExclusion(for: app) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(transcriptBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(panelStroke, lineWidth: 1)
        )
    }

    private var transcriptTextColor: Color {
        if transcript.isEmpty {
            return secondaryTextColor
        } else {
            return primaryTextColor
        }
    }

    private func actionPresentation(for action: OverlayAction) -> ActionButtonPresentation {
        action.presentation(
            isRecording: isRecording,
            isMimicTyping: mimicTypeController.isRunning,
            isMirrorRunning: mirrorWindowController.isRunning,
            primaryWidth: actionButtonWidth,
            secondaryWidth: secondaryActionButtonWidth
        )
    }

    private func headerActionPresentation(for action: OverlayAction) -> ActionButtonPresentation {
        action.presentation(
            isRecording: isRecording,
            isMimicTyping: mimicTypeController.isRunning,
            isMirrorRunning: mirrorWindowController.isRunning,
            primaryWidth: actionButtonWidth,
            secondaryWidth: headerActionButtonWidth
        )
    }

    private func perform(_ action: OverlayAction) {
        switch action {
        case .toggleTranscription:
            toggleMockSpeakerTranscription()
        case .requestAnswer:
            requestMockAnswer()
        case .copyTranscript:
            copyTranscriptToPasteboard()
        case .clearTranscript:
            clearTranscript()
        case .captureScreenshot:
            captureScreenshot()
        case .mimicType:
            triggerMimicType()
        case .mirrorWindow:
            triggerMirrorWindow()
        }
    }

    private func copyTranscriptToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        status = "Copied"
    }

    private func startMockSpeakerTranscription() {
        transcriptTask?.cancel()
        transcriptTask = nil
        isRecording = true
        status = "Transcribing"

        guard !mockSpeakerTranscriptParagraphs.isEmpty else {
            transcript = ""
            return
        }

        let tokens = mockSpeakerTranscriptParagraphs.enumerated().flatMap { index, paragraph in
            let words = paragraph.split(separator: " ").map(String.init)
            if index < mockSpeakerTranscriptParagraphs.count - 1 {
                return words + ["\n"]
            } else {
                return words
            }
        }

        guard let firstToken = tokens.first else {
            transcript = ""
            return
        }

        transcript = firstToken

        transcriptTask = Task {
            for token in tokens.dropFirst() {
                try? await Task.sleep(nanoseconds: mockTranscriptDelay(for: token))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if token == "\n" {
                        transcript += "\n"
                    } else if transcript.isEmpty || transcript.hasSuffix("\n") {
                        transcript += token
                    } else {
                        transcript += " " + token
                    }
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isRecording = false
                status = "Mock Complete"
                transcriptTask = nil
            }
        }
    }

    private func mockTranscriptDelay(for token: String) -> UInt64 {
        if token == "\n" {
            return 240_000_000
        }

        if token.hasSuffix(".") || token.hasSuffix("!") || token.hasSuffix("?") {
            return 180_000_000
        }

        if token.hasSuffix(",") {
            return 130_000_000
        }

        return 90_000_000
    }

    private func toggleMockSpeakerTranscription() {
        if isRecording {
            stopMockSpeakerTranscription()
        } else {
            startMockSpeakerTranscription()
        }
    }

    private func stopMockSpeakerTranscription() {
        transcriptTask?.cancel()
        transcriptTask = nil
        isRecording = false
        status = "Stopped"
    }

    private func requestMockAnswer() {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "No Transcript"
            return
        }

        // Placeholder hook until backend turns transcript text into an actual answer flow.
        status = "Answer Pending"
    }

    private func clearTranscript() {
        transcriptTask?.cancel()
        transcriptTask = nil
        transcript = ""
        isRecording = false
        status = "Ready"
    }

    private func captureScreenshot() {
        status = "Saving Screenshot"

        Task {
            do {
                try await ScreenshotCaptureService
                    .captureAndCopyToClipboardExcludingStealthXWindows()

                await MainActor.run {
                    status = "Screenshot Copied"
                }
            } catch {
                await MainActor.run {
                    status = "Screenshot Failed"
                }
            }
        }
    }

    private func triggerMimicType() {
        mimicTypeController.toggleTyping { nextStatus in
            status = nextStatus
        }
    }

    private func beginMirrorWindowSetup() {
        refreshMirrorExclusionApps()
        contentMode = .mirrorSetup
        status = "Select Exclusions"
    }

    private func dismissMirrorWindowSetup() {
        contentMode = .transcript
        status = mirrorSelectionStatus
    }

    private func refreshMirrorExclusionApps() {
        let apps = MirrorExclusionApp.availableExclusions()
        let availableIDs = Set(apps.map(\.id))
        let preservedSelections = excludedMirrorAppIDs.intersection(availableIDs)
        let alwaysExcludedIDs = Set(apps.filter(\.isAlwaysExcluded).map(\.id))

        mirrorExclusionApps = apps

        excludedMirrorAppIDs = preservedSelections.union(alwaysExcludedIDs)
    }

    private func toggleMirrorExclusion(for app: MirrorExclusionApp) {
        guard !app.isAlwaysExcluded else { return }

        if excludedMirrorAppIDs.contains(app.id) {
            excludedMirrorAppIDs.remove(app.id)
        } else {
            excludedMirrorAppIDs.insert(app.id)
        }
    }

    private var mirrorSelectionSummary: String {
        let count = excludedMirrorAppIDs.count
        if count == 1 {
            return "1 app selected"
        } else {
            return "\(count) apps selected"
        }
    }

    private var mirrorSelectionStatus: String {
        let count = excludedMirrorAppIDs.count
        if count == 0 {
            return "Mirror Ready"
        } else if count == 1 {
            return "1 App Excluded"
        } else {
            return "\(count) Apps Excluded"
        }
    }

    private func createMirrorWindow() {
        let selectedBundleIDs = mirrorExclusionApps
            .filter { excludedMirrorAppIDs.contains($0.id) }
            .compactMap(\.bundleIdentifier)

        mirrorWindowController.createOrUpdateMirror(excludingBundleIDs: selectedBundleIDs) { nextStatus in
            status = nextStatus
            if nextStatus == "Mirror Running" {
                contentMode = .transcript
            }
        }
    }

    private var mirrorSetupButtonTitle: String {
        mirrorWindowController.isRunning ? "Stop Mirror" : "Create Mirror"
    }

    private func triggerMirrorWindow() {
        if mirrorWindowController.isRunning {
            stopMirrorWindow(shouldDismissSetup: true)
        } else {
            beginMirrorWindowSetup()
        }
    }

    private func toggleMirrorFromSetup() {
        if mirrorWindowController.isRunning {
            stopMirrorWindow(shouldDismissSetup: false)
        } else {
            createMirrorWindow()
        }
    }

    private func stopMirrorWindow(shouldDismissSetup: Bool) {
        mirrorWindowController.stopMirror { nextStatus in
            status = nextStatus
            if shouldDismissSetup {
                contentMode = .transcript
            }
        }
    }

    private func quitApplication() {
        status = "Quitting"

        transcriptTask?.cancel()
        transcriptTask = nil
        isRecording = false

        mimicTypeController.forceStopForAppQuit()

        if mirrorWindowController.isRunning {
            mirrorWindowController.stopMirror { _ in
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}

private struct ActionButton: View {
    let presentation: ActionButtonPresentation
    let perform: () -> Void
    var controlSize: ControlSize = .regular

    var body: some View {
        Button {
            perform()
        } label: {
            ActionButtonLabel(presentation: presentation)
        }
        .frame(width: presentation.width)
        .buttonStyle(.bordered)
        .controlSize(controlSize)
    }
}

private struct ActionButtonRow: View {
    let actions: [OverlayAction]
    let presentation: (OverlayAction) -> ActionButtonPresentation
    let perform: (OverlayAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                ActionButton(
                    presentation: presentation(action),
                    perform: { perform(action) }
                )
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ActionButtonLabel: View {
    let presentation: ActionButtonPresentation

    var body: some View {
        Label(presentation.title, systemImage: presentation.systemImage)
            .font(.system(size: 12, weight: .regular))
            .imageScale(.medium)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }
}

private struct MirrorExclusionAppRow: View {
    let app: MirrorExclusionApp
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Group {
            if app.isAlwaysExcluded {
                rowContent
            } else {
                Button {
                    toggle()
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            MirrorExclusionAppIcon(icon: app.icon)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)

                    if app.isCurrentApp {
                        badge("This App")
                    }

                    if app.isAlwaysExcluded {
                        badge("Always Excluded")
                    }
                }

                if let bundleIdentifier = app.bundleIdentifier {
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? Color(nsColor: .controlAccentColor)
                        : Color(nsColor: .tertiaryLabelColor)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                        ? Color(nsColor: .controlAccentColor).opacity(0.08)
                        : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color(nsColor: .separatorColor).opacity(isSelected ? 0.3 : 0.12),
                    lineWidth: 1
                )
        )
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }
}

private struct MirrorExclusionAppIcon: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(4)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct TranscriptTextView: NSViewRepresentable {
    var text: String

    private static let textInsets = NSSize(width: 10, height: 10)
    private static let trailingGutter: CGFloat = 10
    private static let font = NSFont.systemFont(ofSize: 14)
    private static let textColor = NSColor.labelColor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textColor = Self.textColor
        textView.textContainerInset = Self.textInsets
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: Self.containerWidth(for: scrollView.contentSize.width),
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        Self.applyStyledText(text, to: textView)

        scrollView.documentView = textView

        context.coordinator.installObservers(for: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator
        let shouldFollowLatest = coordinator.shouldFollowLatest || coordinator.isNearBottom(scrollView)
        let contentSize = scrollView.contentSize

        if textView.frame.width != contentSize.width {
            textView.setFrameSize(NSSize(width: contentSize.width, height: textView.frame.height))
        }

        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.textContainer?.containerSize = NSSize(
            width: Self.containerWidth(for: contentSize.width),
            height: CGFloat.greatestFiniteMagnitude
        )

        if textView.string != text {
            Self.applyStyledText(text, to: textView)
        }

        if let textContainer = textView.textContainer,
            let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
        }

        coordinator.shouldFollowLatest = shouldFollowLatest

        guard shouldFollowLatest, !text.isEmpty else { return }

        coordinator.scrollToBottom(in: scrollView, animated: true)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.removeObservers()
    }

    private static func containerWidth(for contentWidth: CGFloat) -> CGFloat {
        max(0, contentWidth - (textInsets.width * 2) - trailingGutter)
    }

    private static func applyStyledText(_ text: String, to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]

        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
    }

    final class Coordinator: NSObject {
        private let bottomThreshold: CGFloat = 24
        private var observedClipView: NSClipView?
        var shouldFollowLatest = true

        func installObservers(for scrollView: NSScrollView) {
            removeObservers()
            observedClipView = scrollView.contentView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBoundsChange),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        func removeObservers() {
            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }
            observedClipView = nil
        }

        func isNearBottom(_ scrollView: NSScrollView) -> Bool {
            let visibleMaxY = scrollView.contentView.bounds.maxY
            let documentHeight = scrollView.documentView?.bounds.height ?? 0
            return documentHeight - visibleMaxY <= bottomThreshold
        }

        func scrollToBottom(in scrollView: NSScrollView, animated: Bool) {
            guard let documentView = scrollView.documentView else { return }

            let targetY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let targetPoint = NSPoint(x: 0, y: targetY)

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    scrollView.contentView.animator().setBoundsOrigin(targetPoint)
                } completionHandler: {
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            } else {
                scrollView.contentView.setBoundsOrigin(targetPoint)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        @objc private func handleBoundsChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                let scrollView = clipView.superview as? NSScrollView else { return }

            shouldFollowLatest = isNearBottom(scrollView)
        }

        deinit {
            removeObservers()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(showsWindowBounds: true)
            .frame(width: 420, height: 300)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
