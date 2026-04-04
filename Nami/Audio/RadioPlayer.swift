import AVFoundation
import Network
import os
import SwiftUI

private let logger = Logger(subsystem: "com.nami.app", category: "RadioPlayer")

enum SignalQuality: Equatable {
    case excellent
    case good
    case poor
    case none
}

@MainActor
@Observable
final class RadioPlayer {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var stallObserver: NSKeyValueObservation?
    private var qualityTimer: Timer?
    @ObservationIgnored
    nonisolated(unsafe) private var pathMonitor: NWPathMonitor?
    @ObservationIgnored
    private let monitorQueue = DispatchQueue(label: "com.nami.network-monitor")

    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var signalQuality: SignalQuality = .none
    private(set) var isReconnecting = false
    @ObservationIgnored
    private var observedBitrate: Double = 0
    @ObservationIgnored
    private var stallCount: Int = 0
    var currentStation: Station

    private var retryCount = 0
    @ObservationIgnored
    nonisolated(unsafe) private var retryTask: Task<Void, Never>?
    private static let maxRetries = 5
    private static let baseRetryDelay: TimeInterval = 2.0
    private static let qualityMonitoringInterval: TimeInterval = 2.0
    private static let highBitrateThreshold: Double = 128_000
    private static let mediumBitrateThreshold: Double = 64_000
    private static let excellentScoreThreshold = 5
    private static let goodScoreThreshold = 3
    private static let maxStallPenalty = 2

    @ObservationIgnored
    @AppStorage("volume") private var storedVolume: Double = 0.5

    @ObservationIgnored
    @AppStorage("stationId") private var storedStationId: String = Station.shonanBeachFM.id

    init() {
        let savedId = UserDefaults.standard.string(forKey: "stationId") ?? Station.shonanBeachFM.id
        self.currentStation = Station.allStations.first { $0.id == savedId } ?? .shonanBeachFM
        startNetworkMonitoring()
    }

    func setStation(_ station: Station) {
        let wasPlaying = isPlaying
        if wasPlaying {
            pause()
        }
        currentStation = station
        storedStationId = station.id
        logger.info("Station changed to \(station.name)")
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

    // MARK: - Playback

    func play() {
        cancelReconnect()
        errorMessage = nil
        isLoading = true
        startPlayback()
        logger.info("Playing \(self.currentStation.name)")
    }

    func pause() {
        cancelReconnect()
        cleanupPlayer()
        isPlaying = false
        isLoading = false
        logger.info("Paused")
    }

    private func startPlayback() {
        cleanupPlayer()

        playerItem = AVPlayerItem(url: currentStation.streamURL)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume

        observePlayerStatus()
        startQualityMonitoring()

        player?.play()
        isPlaying = true
    }

    // MARK: - Auto-Reconnect

    private func attemptReconnect() {
        retryTask?.cancel()
        retryTask = nil

        guard retryCount < Self.maxRetries else {
            logger.warning("Max retries (\(Self.maxRetries)) reached, giving up")
            isReconnecting = false
            errorMessage = "Stream unavailable. Tap play to try again."
            return
        }

        retryCount += 1
        isReconnecting = true
        let delay = Self.baseRetryDelay * pow(2.0, Double(retryCount - 1))
        logger.info("Reconnect attempt \(self.retryCount)/\(Self.maxRetries) in \(delay, format: .fixed(precision: 1))s")

        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.performReconnect()
        }
    }

    private func performReconnect() {
        guard isReconnecting else { return }
        startPlayback()
        logger.info("Reconnecting to \(self.currentStation.name)")
    }

    private func cancelReconnect() {
        retryTask?.cancel()
        retryTask = nil
        retryCount = 0
        isReconnecting = false
    }

    func handleWake() {
        if isPlaying {
            logger.info("Wake detected while playing, reconnecting")
            retryCount = 0
            isReconnecting = true
            startPlayback()
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handleNetworkChange(path)
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }

    private func handleNetworkChange(_ path: NWPath) {
        if path.status == .satisfied {
            logger.info("Network available")
            if isReconnecting {
                retryCount = 0
                attemptReconnect()
            }
        } else {
            logger.warning("Network lost")
            if isPlaying && !isReconnecting {
                cleanupPlayer()
                isPlaying = false
                isReconnecting = true
                errorMessage = "No network connection"
            }
        }
    }

    // MARK: - Quality Monitoring

    private func startQualityMonitoring() {
        let timer = Timer(timeInterval: Self.qualityMonitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAccessLog()
                self?.updateSignalQuality()
            }
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

    // MARK: - KVO Observers

    private func observePlayerStatus() {
        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                self?.handleStatusChange(status)
            }
        }

        bufferObserver = playerItem?.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateSignalQuality()
            }
        }

        stallObserver = playerItem?.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateSignalQuality()
            }
        }
    }

    private func updateSignalQuality() {
        guard isPlaying, let item = playerItem else {
            if signalQuality != .none { signalQuality = .none }
            return
        }

        let bufferScore: Int
        if item.isPlaybackBufferEmpty {
            bufferScore = 0
        } else if item.isPlaybackLikelyToKeepUp {
            bufferScore = item.isPlaybackBufferFull ? 3 : 2
        } else {
            bufferScore = 1
        }

        let bitrateScore: Int
        if observedBitrate <= 0 {
            bitrateScore = 1
        } else if observedBitrate >= Self.highBitrateThreshold {
            bitrateScore = 3
        } else if observedBitrate >= Self.mediumBitrateThreshold {
            bitrateScore = 2
        } else {
            bitrateScore = 1
        }

        let stallPenalty = min(stallCount, Self.maxStallPenalty)
        let totalScore = bufferScore + bitrateScore - stallPenalty

        let newQuality: SignalQuality
        if totalScore >= Self.excellentScoreThreshold {
            newQuality = .excellent
        } else if totalScore >= Self.goodScoreThreshold {
            newQuality = .good
        } else {
            newQuality = .poor
        }

        if newQuality != signalQuality {
            signalQuality = newQuality
        }
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            isLoading = false
            isReconnecting = false
            retryCount = 0
            errorMessage = nil
            logger.info("Stream ready")
        case .failed:
            isLoading = false
            isPlaying = false
            let error = playerItem?.error?.localizedDescription ?? "Failed to load stream"
            errorMessage = error
            logger.error("Stream failed: \(error)")
            attemptReconnect()
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
        if signalQuality != .none { signalQuality = .none }
        observedBitrate = 0
        stallCount = 0
    }

    deinit {
        pathMonitor?.cancel()
        retryTask?.cancel()
    }
}
