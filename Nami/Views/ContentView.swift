import ServiceManagement
import SwiftUI

/// Shonan Indigo theme tokens. Muted, misty coastal palette: lower saturation
/// and gentler contrast than a pure navy for a calmer feel.
enum Theme {
    static let indigoTop = Color(red: 38 / 255, green: 49 / 255, blue: 64 / 255)  // #263140
    static let indigoDeep = Color(red: 27 / 255, green: 36 / 255, blue: 47 / 255)  // #1B242F
    static let foam = Color(red: 236 / 255, green: 235 / 255, blue: 227 / 255)  // #ECEBE3
    static let seafoam = Color(red: 143 / 255, green: 195 / 255, blue: 181 / 255)  // #8FC3B5 (muted sea glass)
    static let coral = Color(red: 216 / 255, green: 160 / 255, blue: 140 / 255)  // #D8A08C (muted terracotta)
}

/// A field of parallel contour lines flowing as one body of water, the calm
/// signature of Mori Yuzan's Hamonshu. Lines bunch and swell toward the middle;
/// while `playing` the current drifts from the timeline, and it settles when
/// paused. One layer, sitting behind the whole popover.
struct DriftingCurrent: View {
    var playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineCount = 7

    var body: some View {
        TimelineView(.animation(paused: !playing || reduceMotion)) { timeline in
            let t = playing ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                // The current sits in the lower portion so the frequency stays clear.
                let top = size.height * 0.34
                let bottom = size.height * 0.98
                let gap = (bottom - top) / CGFloat(lineCount - 1)
                for i in 0..<lineCount {
                    let frac = Double(i) / Double(lineCount - 1)
                    let y0 = top + CGFloat(i) * gap
                    let env = 0.6 + 0.9 * sin(frac * .pi)
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        let u = Double(x / size.width)
                        let y = y0
                            + CGFloat(sin(u * .pi * 3 + t * 0.8 + Double(i) * 0.28) * Double(gap) * 0.75 * env)
                            + CGFloat(sin(u * .pi * 6 - t * 0.5 + Double(i) * 0.5) * Double(gap) * 0.26 * env)
                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        x += 3
                    }
                    let alpha = 0.05 + 0.12 * sin(frac * .pi)
                    ctx.stroke(path, with: .color(Theme.seafoam.opacity(alpha)), lineWidth: 0.7)
                }
            }
        }
    }
}

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var showTimePicker = false
    @AppStorage("sleepTimerHour") private var sleepTimerHour = 22
    @AppStorage("sleepTimerMinute") private var sleepTimerMinute = 30
    @State private var selectedTime = Date()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private func signalBars(for quality: SignalQuality) -> some View {
        HStack(spacing: 1.5) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(signalColor(for: index, quality: quality))
                    .frame(width: 2.5, height: CGFloat(4 + index * 2))
            }
        }
        .frame(width: 12, height: 8, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Signal \(signalLabel(for: quality))")
    }

    private func signalLabel(for quality: SignalQuality) -> String {
        switch quality {
        case .excellent: "excellent"
        case .good: "good"
        case .poor: "poor"
        case .none: "none"
        }
    }

    private func signalColor(for bar: Int, quality: SignalQuality) -> Color {
        switch quality {
        case .excellent:
            return Theme.seafoam
        case .good:
            return bar < 2 ? Theme.seafoam : Theme.foam.opacity(0.25)
        case .poor:
            return bar < 1 ? Theme.coral : Theme.foam.opacity(0.25)
        case .none:
            return Theme.foam.opacity(0.25)
        }
    }

    /// One fixed-height line under the station name so status changes never shift the layout.
    private var statusLine: some View {
        Group {
            if appState.isReconnecting {
                Text("Reconnecting…")
                    .foregroundStyle(Theme.foam.opacity(0.5))
            } else if let error = appState.errorMessage {
                Text(error)
                    .foregroundStyle(Theme.coral)
            } else if appState.isLoading {
                Text("Connecting…")
                    .foregroundStyle(Theme.foam.opacity(0.5))
            } else if appState.isPlaying {
                (Text("Live").foregroundStyle(Theme.seafoam)
                    + Text(" · \(appState.currentStation.streamType)\(bitrateSuffix)")
                    .foregroundStyle(Theme.foam.opacity(0.5)))
            } else {
                Text("\(appState.currentStation.location) · \(appState.currentStation.streamType)")
                    .foregroundStyle(Theme.foam.opacity(0.5))
            }
        }
        .font(.system(size: 10))
        .lineLimit(1)
        .frame(height: 14)
    }

    private var bitrateSuffix: String {
        appState.streamBitrate > 0 ? " · \(Int(appState.streamBitrate / 1000)) kbps" : ""
    }

    private func sleepPresetChip(minutes: Int) -> some View {
        Button("\(minutes) min") {
            appState.setSleepTimer(at: Date().addingTimeInterval(TimeInterval(minutes * 60)))
            showTimePicker = false
        }
        .font(.system(size: 10))
        .buttonStyle(.plain)
        .foregroundStyle(Theme.foam.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(Capsule().stroke(Theme.foam.opacity(0.25), lineWidth: 1))
        .help("Sleep in \(minutes) minutes")
    }

    /// Oversized brush 波 that bleeds off the top-right so the UI reads as
    /// printed on the artwork. Lives in a background layer so it never drives
    /// the panel's layout; a radial fade toward the lower-left protects text.
    var body: some View {
        content
            .frame(width: 242)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Theme.indigoTop, Theme.indigoDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                    DriftingCurrent(playing: appState.isPlaying)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                selectedTime = Calendar.current.date(from: DateComponents(hour: sleepTimerHour, minute: sleepTimerMinute)) ?? Date()
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Frequency display
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appState.currentStation.frequency)
                        .font(.custom("ShipporiMincho-Medium", size: 42))
                        .monospacedDigit()
                        .foregroundStyle(Theme.foam)
                    if appState.currentStation.isFrequencyNumeric {
                        Text("MHz")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.foam.opacity(0.5))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(appState.currentStation.frequency) megahertz")

                // Station selector
                Menu {
                    ForEach(Station.allStations) { station in
                        Button {
                            appState.currentStation = station
                        } label: {
                            if station == appState.currentStation {
                                Label(stationMenuTitle(for: station), systemImage: "checkmark")
                            } else {
                                Text(stationMenuTitle(for: station))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        signalBars(for: appState.isPlaying ? appState.signalQuality : .none)
                        Text(appState.currentStation.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(
                                appState.isPlaying && appState.signalQuality == .poor
                                    ? Theme.coral : Theme.foam.opacity(0.9)
                            )
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.foam.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Station: \(appState.currentStation.name)")
                .help("Select station")

                statusLine
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Controls
            HStack(spacing: 18) {
                Button(action: { appState.previousStation() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.foam.opacity(0.65))
                .accessibilityLabel("Previous station")
                .help("Previous station")

                Button(action: { appState.togglePlayback() }) {
                    ZStack {
                        Circle().fill(Theme.seafoam)
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(Theme.indigoDeep)
                        } else {
                            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.indigoDeep)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading)
                .accessibilityLabel(appState.isPlaying ? "Pause" : "Play")
                .help(appState.isPlaying ? "Pause" : "Play")

                Button(action: { appState.nextStation() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.foam.opacity(0.65))
                .accessibilityLabel("Next station")
                .help("Next station")
            }
            .padding(.bottom, 12)

            // Volume
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.foam.opacity(0.45))

                Slider(
                    value: Binding(
                        get: { Double(appState.volume) },
                        set: { appState.volume = Float($0) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                .tint(Theme.seafoam)
                .accessibilityLabel("Volume")
                .help("Volume")

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.foam.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // Sleep Timer
            VStack(spacing: 8) {
                Button {
                    if appState.isSleepTimerActive {
                        selectedTime = appState.sleepTimerEndDate ?? selectedTime
                        showTimePicker = true
                    } else {
                        showTimePicker.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: appState.isSleepTimerActive ? "moon.fill" : "moon")
                            .font(.system(size: 10))
                            .foregroundStyle(appState.isSleepTimerActive ? Theme.seafoam : Theme.foam.opacity(0.6))
                        if let endDate = appState.sleepTimerEndDate {
                            Text("Sleep at \(endDate, format: .dateTime.hour().minute())")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.foam.opacity(0.85))
                        } else {
                            Text("Sleep Timer")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.foam.opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.isSleepTimerActive ? "Sleep timer active" : "Set sleep timer")
                .help("Sleep timer")

                if showTimePicker {
                    HStack(spacing: 6) {
                        sleepPresetChip(minutes: 15)
                        sleepPresetChip(minutes: 30)
                        sleepPresetChip(minutes: 60)
                    }

                    HStack(spacing: 8) {
                        DatePicker(
                            "",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .frame(width: 70)

                        Button(appState.isSleepTimerActive ? "Update" : "Set") {
                            let calendar = Calendar.current
                            sleepTimerHour = calendar.component(.hour, from: selectedTime)
                            sleepTimerMinute = calendar.component(.minute, from: selectedTime)
                            appState.setSleepTimer(at: selectedTime)
                            showTimePicker = false
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.seafoam)

                        if appState.isSleepTimerActive {
                            Button("Off") {
                                appState.cancelSleepTimer()
                                showTimePicker = false
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.coral)
                        }
                    }
                }
            }
            .padding(.bottom, 12)

            // Footer controls
            VStack(spacing: 0) {
                Divider()
                    .overlay(Theme.foam.opacity(0.12))

                HStack {
                    Menu {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Settings")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7))
                        }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Settings")
                    .help("Settings")

                    Spacer()

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Nami")
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.foam.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 10)
            }
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = !enabled
                }
            }
        }
    }

    private func stationMenuTitle(for station: Station) -> String {
        "\(station.name) · \(station.frequency) MHz · \(station.location)"
    }
}

#Preview {
    ContentView(appState: AppState())
}
