import SwiftUI
import AppKit

struct ContentView: View {
    var showsWindowBounds = false

    @State private var transcript = ""
    @State private var isRecording = false
    @State private var status = "Ready"
    @FocusState private var editorFocused: Bool

    private let graphiteText = Color(red: 0.18, green: 0.18, blue: 0.15)
    private let macAccentColor = Color(red: 0.82, green: 0.29, blue: 0.22)
    private let unixAccentColor = Color(red: 0.13, green: 0.45, blue: 0.61)
    private let windowBackgroundColor = Color(red: 0.72, green: 0.72, blue: 0.68)

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

                TextEditor(text: $transcript)
                    .focused($editorFocused)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.15, green: 0.14, blue: 0.12))
                    .scrollContentBackground(.hidden)
                    .padding(10)
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

                HStack(spacing: 8) {
                    Button {
                        isRecording = true
                        status = "Recording"
                    } label: {
                        Label("Start", systemImage: "mic.fill")
                    }
                    .buttonStyle(StealthButtonStyle(kind: .primary, active: isRecording))

                    Button {
                        isRecording = false
                        status = "Stopped"
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(StealthButtonStyle(kind: .danger))

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(transcript, forType: .string)
                        status = "Copied"
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
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
                        editorFocused = true
                        status = "Typing"
                    } label: {
                        Label("Type", systemImage: "keyboard")
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

enum StealthButtonKind {
    case normal
    case primary
    case danger
}

struct StealthButtonStyle: ButtonStyle {
    var kind: StealthButtonKind = .normal
    var active: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor(configuration: configuration))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minWidth: 74)
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
