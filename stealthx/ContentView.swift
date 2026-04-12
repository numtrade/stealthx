import SwiftUI
import AppKit

struct ContentView: View {
    var showsWindowBounds = false

    @State private var transcript = ""
    @State private var isRecording = false
    @State private var status = "Ready"
    @State private var transcriptTask: Task<Void, Never>?

    private let graphiteText = Color(red: 0.18, green: 0.18, blue: 0.15)
    private let macAccentColor = Color(red: 0.82, green: 0.29, blue: 0.22)
    private let unixAccentColor = Color(red: 0.13, green: 0.45, blue: 0.61)
    private let windowBackgroundColor = Color(red: 0.72, green: 0.72, blue: 0.68)
    private let transcriptPlaceholder =
        "Speaker transcript appears here after Start begins speaker-output capture."
    // Mock speaker-side transcript until backend wires live system-audio transcription.
    private let mockSpeakerTranscriptLines = [
        "00:00 Speaker: Starting speaker-output transcription demo.",
        "00:01 Speaker: This transcript is hard-coded for the backend handoff.",
        "00:03 Speaker: Replace these lines with live text generated from audio flowing to the speaker.",
        "00:05 Speaker: Auto-follow should stay smooth while the transcript grows.",
        "00:07 Speaker: If the user scrolls up to review older lines, live updates should not yank the view back down.",
        "00:09 Speaker: Once the user returns near the bottom, new lines can resume following the latest audio.",
        "00:11 Speaker: Backend hook point: swap this mocked stream for real speaker-output transcription events.",
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(panelBorderColor, lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.48), lineWidth: 1)
                        .padding(1)
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.58),
                                        Color.black.opacity(0.08),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Circle()
                            .fill(recordIndicatorFill)
                            .padding(2.5)
                    }
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.28), radius: 0, x: 0, y: 1)

                    brandView

                    Spacer()

                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(statusFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.black.opacity(0.22), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.42), lineWidth: 1)
                                .padding(1)
                        )
                }

                transcriptPanel

                HStack(spacing: 4) {
                    Button {
                        toggleMockSpeakerTranscription()
                    } label: {
                        Label(
                            isRecording ? "Stop" : "Start",
                            systemImage: isRecording ? "stop.fill" : "speaker.wave.2.fill"
                        )
                    }
                    .buttonStyle(
                        StealthButtonStyle(
                            kind: isRecording ? .danger : .primary,
                            active: isRecording
                        )
                    )

                    Button {
                        requestMockAnswer()
                    } label: {
                        Label("Answer", systemImage: "text.bubble.fill")
                    }
                    .buttonStyle(StealthButtonStyle())

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(transcript, forType: .string)
                        status = "Copied"
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(StealthButtonStyle())

                    Button {
                        clearTranscript()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(StealthButtonStyle())

                    Spacer()
                }

                HStack(spacing: 8) {
                    Button {
                        status = "Screenshot clicked"
                    } label: {
                        Label("Screenshot", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(StealthButtonStyle())

                    Button {
                        status = "Mimic Type clicked"
                    } label: {
                        Label("Mimic Type", systemImage: "keyboard")
                    }
                    .buttonStyle(StealthButtonStyle())

                    Spacer()
                }
            }
            .padding(16)
        }
        .padding(8)
        .background(windowBackgroundColor)
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

    private var panelFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.89, green: 0.89, blue: 0.85),
                Color(red: 0.78, green: 0.78, blue: 0.74),
                Color(red: 0.66, green: 0.66, blue: 0.62),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var panelBorderColor: Color {
        Color(red: 0.38, green: 0.38, blue: 0.34)
    }

    private var editorFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.92, blue: 0.88),
                Color(red: 0.86, green: 0.85, blue: 0.80),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var editorBorderColor: Color {
        Color(red: 0.47, green: 0.46, blue: 0.42)
    }

    private var recordIndicatorFill: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.40, blue: 0.38),
                    Color(red: 0.58, green: 0.12, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.80, blue: 0.77),
                    Color(red: 0.53, green: 0.53, blue: 0.49),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var statusFill: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.79, blue: 0.78),
                    Color(red: 0.75, green: 0.48, blue: 0.46),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.92, blue: 0.88),
                    Color(red: 0.77, green: 0.76, blue: 0.71),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var statusTextColor: Color {
        if isRecording {
            return Color(red: 0.35, green: 0.08, blue: 0.08)
        } else {
            return Color(red: 0.29, green: 0.28, blue: 0.25)
        }
    }

    private var brandView: some View {
        HStack(spacing: 8) {

            HStack(spacing: 0) {
                Text("Mac")
                    .foregroundStyle(macAccentColor)
                Text("Unix")
                    .foregroundStyle(unixAccentColor)
            }
            .font(.system(size: 18, weight: .semibold))
            .tracking(0.2)
        }
    }

    private var transcriptPanel: some View {
        ZStack(alignment: .topLeading) {
            TranscriptTextView(text: transcript)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if transcript.isEmpty {
                Text(transcriptPlaceholder)
                    .font(.system(size: 14))
                    .foregroundStyle(transcriptTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(editorFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(editorBorderColor, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 1)
                .padding(1)
                .mask(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var transcriptTextColor: Color {
        if transcript.isEmpty {
            return Color(red: 0.42, green: 0.40, blue: 0.36)
        } else {
            return Color(red: 0.15, green: 0.14, blue: 0.12)
        }
    }

    private func startMockSpeakerTranscription() {
        transcriptTask?.cancel()
        transcriptTask = nil
        transcript = ""
        isRecording = true
        status = "Speaker -> Text"

        transcriptTask = Task {
            for (index, line) in mockSpeakerTranscriptLines.enumerated() {
                let delay = index == 0 ? 250_000_000 : 850_000_000
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if transcript.isEmpty {
                        transcript = line
                    } else {
                        transcript += "\n" + line
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

    private func brandPill(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: 4, height: 11)
            .overlay(
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
            )
    }
}

private struct TranscriptTextView: NSViewRepresentable {
    var text: String

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

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = NSColor(calibratedRed: 0.15, green: 0.14, blue: 0.12, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text

        scrollView.documentView = textView

        context.coordinator.installObservers(for: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator
        let shouldFollowLatest = coordinator.shouldFollowLatest || coordinator.isNearBottom(scrollView)

        if textView.string != text {
            textView.string = text
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

enum StealthButtonKind {
    case normal
    case primary
    case danger
}

struct StealthButtonStyle: ButtonStyle {
    var kind: StealthButtonKind = .normal
    var active: Bool = false
    var width: CGFloat = 90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .imageScale(.small)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(foregroundColor(configuration: configuration))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(innerHighlightColor(configuration: configuration), lineWidth: 1)
                    .padding(1)
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.18),
                radius: 0,
                x: 0,
                y: 1
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary where active:
            return Color(red: 0.31, green: 0.09, blue: 0.09)
        case .danger:
            return Color(red: 0.20, green: 0.18, blue: 0.16)
        case .primary, .normal:
            return Color(red: 0.18, green: 0.18, blue: 0.16)
        }
    }

    private func backgroundFill(configuration: Configuration) -> LinearGradient {
        switch kind {
        case .primary where active:
            return LinearGradient(
                colors: [
                    Color(
                        red: configuration.isPressed ? 0.84 : 0.95,
                        green: configuration.isPressed ? 0.50 : 0.68,
                        blue: configuration.isPressed ? 0.49 : 0.70
                    ),
                    Color(
                        red: configuration.isPressed ? 0.58 : 0.72,
                        green: configuration.isPressed ? 0.22 : 0.28,
                        blue: configuration.isPressed ? 0.20 : 0.27
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .danger:
            return LinearGradient(
                colors: [
                    Color(
                        red: configuration.isPressed ? 0.79 : 0.90,
                        green: configuration.isPressed ? 0.78 : 0.88,
                        blue: configuration.isPressed ? 0.73 : 0.82
                    ),
                    Color(
                        red: configuration.isPressed ? 0.63 : 0.74,
                        green: configuration.isPressed ? 0.62 : 0.71,
                        blue: configuration.isPressed ? 0.58 : 0.64
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .primary, .normal:
            return LinearGradient(
                colors: [
                    Color(
                        red: configuration.isPressed ? 0.83 : 0.95,
                        green: configuration.isPressed ? 0.83 : 0.94,
                        blue: configuration.isPressed ? 0.79 : 0.90
                    ),
                    Color(
                        red: configuration.isPressed ? 0.68 : 0.78,
                        green: configuration.isPressed ? 0.68 : 0.77,
                        blue: configuration.isPressed ? 0.65 : 0.72
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary where active:
            return Color(
                red: configuration.isPressed ? 0.39 : 0.47,
                green: configuration.isPressed ? 0.10 : 0.12,
                blue: configuration.isPressed ? 0.10 : 0.11
            )
        case .danger:
            return Color(
                red: configuration.isPressed ? 0.36 : 0.43,
                green: configuration.isPressed ? 0.35 : 0.40,
                blue: configuration.isPressed ? 0.31 : 0.34
            )
        case .primary, .normal:
            return Color(
                red: configuration.isPressed ? 0.39 : 0.46,
                green: configuration.isPressed ? 0.39 : 0.44,
                blue: configuration.isPressed ? 0.35 : 0.39
            )
        }
    }

    private func innerHighlightColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary where active:
            return Color.white.opacity(configuration.isPressed ? 0.22 : 0.40)
        case .danger:
            return Color.white.opacity(configuration.isPressed ? 0.24 : 0.46)
        case .primary, .normal:
            return Color.white.opacity(configuration.isPressed ? 0.28 : 0.54)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(showsWindowBounds: true)
            .frame(width: 420, height: 300)
            .background(Color.gray.opacity(0.18))
    }
}
