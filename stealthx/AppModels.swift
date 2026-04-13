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
