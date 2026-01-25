import AVFoundation
import SwiftUI

enum SignalQuality {
    case excellent
    case good
    case poor
    case none
}

@Observable
final class RadioPlayer {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var stallObserver: NSKeyValueObservation?
    private var qualityTimer: Timer?

    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var signalQuality: SignalQuality = .none
    private var observedBitrate: Double = 0
    private var stallCount: Int = 0
    var currentStation: Station

    @ObservationIgnored
    @AppStorage("volume") private var storedVolume: Double = 0.5

    @ObservationIgnored
    @AppStorage("stationId") private var storedStationId: String = Station.shonanBeachFM.id

    init() {
        let savedId = UserDefaults.standard.string(forKey: "stationId") ?? Station.shonanBeachFM.id
        self.currentStation = Station.allStations.first { $0.id == savedId } ?? .shonanBeachFM
    }

    func setStation(_ station: Station) {
        let wasPlaying = isPlaying
        if wasPlaying {
            pause()
        }
        currentStation = station
        storedStationId = station.id
        if wasPlaying {
            play()
        }
    }

    var volume: Float {
        get { Float(storedVolume) }
        set {
            storedVolume = Double(newValue)
            player?.volume = newValue
        }
    }

    func play() {
        errorMessage = nil
        isLoading = true
        stallCount = 0

        cleanupPlayer()

        playerItem = AVPlayerItem(url: currentStation.streamURL)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume

        observePlayerStatus()
        startQualityMonitoring()

        player?.play()
        isPlaying = true
    }

    private func startQualityMonitoring() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAccessLog()
            self?.updateSignalQuality()
        }
        RunLoop.main.add(timer, forMode: .common)
        qualityTimer = timer
    }

    private func checkAccessLog() {
        guard let log = playerItem?.accessLog(),
              let event = log.events.last else { return }

        observedBitrate = event.observedBitrate
        stallCount = event.numberOfStalls
    }

    func pause() {
        qualityTimer?.invalidate()
        qualityTimer = nil
        player?.pause()
        isPlaying = false
        isLoading = false
        signalQuality = .none
        observedBitrate = 0
        stallCount = 0
    }

    private func observePlayerStatus() {
        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleStatusChange(item.status)
            }
        }

        bufferObserver = playerItem?.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateSignalQuality()
            }
        }

        stallObserver = playerItem?.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateSignalQuality()
            }
        }
    }

    private func updateSignalQuality() {
        guard isPlaying, let item = playerItem else {
            signalQuality = .none
            return
        }

        // Buffer-based quality
        let bufferScore: Int
        if item.isPlaybackBufferEmpty {
            bufferScore = 0
        } else if item.isPlaybackLikelyToKeepUp {
            bufferScore = item.isPlaybackBufferFull ? 3 : 2
        } else {
            bufferScore = 1
        }

        // Bitrate-based quality (typical: 64-320 kbps for radio)
        let bitrateScore: Int
        if observedBitrate <= 0 {
            bitrateScore = 1  // Unknown, assume OK
        } else if observedBitrate >= 128_000 {
            bitrateScore = 3  // Good bitrate
        } else if observedBitrate >= 64_000 {
            bitrateScore = 2  // Acceptable
        } else {
            bitrateScore = 1  // Low
        }

        // Stall penalty
        let stallPenalty = min(stallCount, 2)

        // Combined score (0-6, minus stalls)
        let totalScore = bufferScore + bitrateScore - stallPenalty

        if totalScore >= 5 {
            signalQuality = .excellent
        } else if totalScore >= 3 {
            signalQuality = .good
        } else {
            signalQuality = .poor
        }
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            isLoading = false
            errorMessage = nil
        case .failed:
            isLoading = false
            isPlaying = false
            errorMessage = playerItem?.error?.localizedDescription ?? "Failed to load stream"
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func cleanupPlayer() {
        qualityTimer?.invalidate()
        qualityTimer = nil
        statusObserver?.invalidate()
        statusObserver = nil
        bufferObserver?.invalidate()
        bufferObserver = nil
        stallObserver?.invalidate()
        stallObserver = nil
        player?.pause()
        player = nil
        playerItem = nil
        signalQuality = .none
        observedBitrate = 0
        stallCount = 0
    }

    deinit {
        cleanupPlayer()
    }
}
