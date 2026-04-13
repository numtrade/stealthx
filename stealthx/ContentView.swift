import SwiftUI
import AppKit

struct ContentView: View {
    var showsWindowBounds = false

    @State private var transcript = ""
    @State private var isRecording = false
    @State private var status = "Ready"
    @State private var transcriptTask: Task<Void, Never>?

    private let transcriptPlaceholder =
        "Speaker transcript appears here after Start begins speaker-output capture."
    private let actionButtonWidth: CGFloat = 92
    private let secondaryActionButtonWidth: CGFloat = 126
    private let primaryActions = OverlayAction.primaryRow
    private let secondaryActions = OverlayAction.secondaryRow
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

                transcriptPanel

                ActionButtonRow(
                    actions: primaryActions,
                    presentation: actionPresentation(for:),
                    perform: perform
                )

                ActionButtonRow(
                    actions: secondaryActions,
                    presentation: actionPresentation(for:),
                    perform: perform
                )
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

            Text(status)
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
            primaryWidth: actionButtonWidth,
            secondaryWidth: secondaryActionButtonWidth
        )
    }

    private func headerActionPresentation(for action: OverlayAction) -> ActionButtonPresentation {
        action.presentation(
            isRecording: isRecording,
            primaryWidth: actionButtonWidth,
            secondaryWidth: 120
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
            beginMirrorWindowSetup()
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
        status = "Screenshot clicked"
    }

    private func triggerMimicType() {
        status = "Mimic Type clicked"
    }

    private func beginMirrorWindowSetup() {
        // Future hook: open the mirror-window flow and let the backend provide
        // exclusion controls for anything that should stay out of the mirrored view.
        status = "Mirror Setup Pending"
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
