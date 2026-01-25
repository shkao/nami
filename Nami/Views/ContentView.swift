import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

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
            }
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Controls
            HStack(spacing: 8) {
                // Previous
                Button(action: { appState.previousStation() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                // Play/Pause
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

                // Next
                Button(action: { appState.nextStation() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
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

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundStyle(.quaternary)
            .padding(.bottom, 10)
        }
        .frame(width: 200)
    }
}

#Preview {
    ContentView(appState: AppState())
        .background(.background)
}
