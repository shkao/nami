import Foundation
import SwiftUI

@Observable
final class AppState {
    private let radioPlayer = RadioPlayer()
    private var sleepTimer: Timer?
    private var wakeObserver: Any?
    private(set) var sleepTimerEndDate: Date?

    init() {
        // Re-check sleep timer when Mac wakes from sleep
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkSleepTimer()
        }
    }

    deinit {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func checkSleepTimer() {
        guard let endDate = sleepTimerEndDate else { return }
        if Date() >= endDate {
            sleepTimerFired()
        }
    }

    var isPlaying: Bool {
        radioPlayer.isPlaying
    }

    var isSleepTimerActive: Bool {
        sleepTimerEndDate != nil
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

    // MARK: - Sleep Timer

    func setSleepTimer(at targetTime: Date) {
        cancelSleepTimer()

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: targetTime)
        let minute = calendar.component(.minute, from: targetTime)

        // Create today's date with the selected hour/minute
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0

        var fireDate = calendar.date(from: components) ?? targetTime

        // If the time is in the past, schedule for tomorrow
        if fireDate <= Date() {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        sleepTimerEndDate = fireDate

        let interval = fireDate.timeIntervalSinceNow
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.sleepTimerFired()
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
    }

    private func sleepTimerFired() {
        sleepTimerEndDate = nil
        sleepTimer = nil
        pause()
    }
}
