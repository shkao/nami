import Foundation
import SwiftUI

@Observable
final class AppState {
    private let radioPlayer = RadioPlayer()

    var isPlaying: Bool {
        radioPlayer.isPlaying
    }

    var volume: Float {
        get { radioPlayer.volume }
        set { radioPlayer.volume = newValue }
    }

    var errorMessage: String? {
        radioPlayer.errorMessage
    }

    var isLoading: Bool {
        radioPlayer.isLoading
    }

    var signalQuality: SignalQuality {
        radioPlayer.signalQuality
    }

    var currentStation: Station {
        get { radioPlayer.currentStation }
        set { radioPlayer.setStation(newValue) }
    }

    func togglePlayback() {
        if isPlaying {
            radioPlayer.pause()
        } else {
            radioPlayer.play()
        }
    }

    func play() {
        radioPlayer.play()
    }

    func pause() {
        radioPlayer.pause()
    }

    func nextStation() {
        let stations = Station.allStations
        guard let currentIndex = stations.firstIndex(of: currentStation) else { return }
        let nextIndex = (currentIndex + 1) % stations.count
        currentStation = stations[nextIndex]
    }

    func previousStation() {
        let stations = Station.allStations
        guard let currentIndex = stations.firstIndex(of: currentStation) else { return }
        let previousIndex = (currentIndex - 1 + stations.count) % stations.count
        currentStation = stations[previousIndex]
    }
}
