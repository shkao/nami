import ServiceManagement
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var showTimePicker = false
    @State private var selectedTime = Calendar.current.date(from: DateComponents(hour: 22, minute: 30)) ?? Date()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var signalIndicator: some View {
        signalBars(for: appState.isPlaying ? appState.signalQuality : .none)
    }

    private func signalBars(for quality: SignalQuality) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(signalColor(for: index, quality: quality))
                    .frame(width: 2, height: CGFloat(3 + index * 2))
            }
        }
        .frame(width: 10, height: 7, alignment: .bottom)
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
            return .green
        case .good:
            return bar < 2 ? .green : .secondary.opacity(0.3)
        case .poor:
            return bar < 1 ? .orange : .secondary.opacity(0.3)
        case .none:
            return .secondary.opacity(0.3)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Frequency display
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(appState.currentStation.frequency)
                        .font(.system(size: 36, weight: .ultraLight, design: .default))
                        .monospacedDigit()
                    if appState.currentStation.isFrequencyNumeric {
                        Text("MHz")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 2)
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
                                Label(station.name, systemImage: "checkmark")
                            } else {
                                Text(station.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        signalIndicator
                        Text(appState.currentStation.name)
                            .font(.system(size: 11))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Station: \(appState.currentStation.name)")
            }
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Error / reconnecting banner
            if let error = appState.errorMessage {
                HStack(spacing: 4) {
                    if appState.isReconnecting {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                        Text("Reconnecting...")
                            .font(.system(size: 9))
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text(error)
                            .font(.system(size: 9))
                            .lineLimit(2)
                    }
                }
                .foregroundColor(appState.isReconnecting ? .secondary : .red)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Controls
            HStack(spacing: 8) {
                Button(action: { appState.previousStation() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Previous station")

                Button(action: { appState.togglePlayback() }) {
                    Group {
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading)
                .accessibilityLabel(appState.isPlaying ? "Pause" : "Play")

                Button(action: { appState.nextStation() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Next station")
            }
            .padding(.bottom, 8)

            // Volume
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                Slider(
                    value: Binding(
                        get: { Double(appState.volume) },
                        set: { appState.volume = Float($0) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                .accessibilityLabel("Volume")

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Sleep Timer
            VStack(spacing: 6) {
                Button {
                    if appState.isSleepTimerActive {
                        selectedTime = appState.sleepTimerEndDate ?? selectedTime
                        showTimePicker = true
                    } else {
                        showTimePicker.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isSleepTimerActive ? "moon.fill" : "moon")
                            .font(.system(size: 10))
                        if let endDate = appState.sleepTimerEndDate {
                            Text("Off at \(endDate, format: .dateTime.hour().minute())")
                                .font(.system(size: 10))
                        } else {
                            Text("Sleep Timer")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundStyle(appState.isSleepTimerActive ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.isSleepTimerActive ? "Sleep timer active" : "Set sleep timer")

                if showTimePicker {
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
                            appState.setSleepTimer(at: selectedTime)
                            showTimePicker = false
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)

                        if appState.isSleepTimerActive {
                            Button("Off") {
                                appState.cancelSleepTimer()
                                showTimePicker = false
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 12)

            // Footer controls
            HStack(spacing: 12) {
                Toggle(isOn: $launchAtLogin) {
                    Image(systemName: "sunrise")
                        .font(.system(size: 9))
                }
                .toggleStyle(.checkbox)
                .controlSize(.mini)
                .foregroundStyle(.quaternary)
                .accessibilityLabel("Launch at login")
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

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(width: 200)
    }

}

#Preview {
    ContentView(appState: AppState())
        .background(.background)
}
