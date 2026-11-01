import AVFoundation
import Network
import XCTest
@testable import Nami

/// End-to-end reconnect tests: a real AVPlayer plays a live AAC stream from a
/// local server, the test cuts the connection mid-play, and the player has to
/// release the dead player, retry with backoff, and resume once the server is
/// back. No internet access is needed, and the stream is silence. The
/// assertions only read RadioPlayer state.
@MainActor
final class RadioPlayerReconnectTests: XCTestCase {

    private var server: LocalStreamServer!
    private var player: RadioPlayer!

    override func setUp() async throws {
        server = LocalStreamServer(audio: try Self.makeSilentADTS())
        try server.start()
        player = RadioPlayer()
        player.currentStation = Station(
            id: "local-test",
            name: "Local Test FM",
            frequency: "00.0",
            location: "Loopback",
            streamURL: server.streamURL
        )
    }

    override func tearDown() async throws {
        player?.pause()
        server?.stop()
        player = nil
        server = nil
    }

    /// Server drops the connection mid-play, the way a stream server restart or
    /// a dead upstream does. AVPlayer plays out its buffer (about 6 s), then
    /// posts an end notification (handleStreamEnded), not .failed. The first retry, 2 s later, hits the
    /// still-down server and the new item reports .failed: the path fixed in
    /// 33e509a.
    func testDroppedConnectionReleasesPlayerAndResumes() async throws {
        try await playUntilReady()

        server.stop()

        try await waitUntil("stream end after drop", timeout: 12) {
            self.player.errorMessage == "Stream interrupted"
        }
        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(player.isReconnecting, "a reconnect should be scheduled")
        XCTAssertFalse(player.holdsPlayerResources, "ended player should be released")

        try await assertFailedRetryReleasesPlayer(after: "Stream interrupted")
        try await restartServerAndWaitForResume()
    }

    /// Wi-Fi off: NWPathMonitor reports the path unsatisfied and the stream
    /// goes dead. The test injects the path status, since the real monitor
    /// can't be driven. When the path comes back before the server is
    /// reachable again, the first retry fails with .failed.
    func testNetworkPathLossReleasesPlayerAndResumes() async throws {
        try await playUntilReady()

        player.handleNetworkChange(isSatisfied: false)
        server.stop()

        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.errorMessage, "No network connection")
        XCTAssertTrue(player.isReconnecting)
        XCTAssertFalse(player.holdsPlayerResources, "player should be released on path loss")

        player.handleNetworkChange(isSatisfied: true)

        try await assertFailedRetryReleasesPlayer(after: "No network connection")
        try await restartServerAndWaitForResume()
    }

    // MARK: - Steps

    private func playUntilReady() async throws {
        player.play()
        try await waitUntil("readyToPlay", timeout: 5) {
            self.player.isPlaying && !self.player.isLoading
        }
        XCTAssertNil(player.errorMessage)
        XCTAssertTrue(player.holdsPlayerResources)
    }

    /// Waits for the first retry (2 s backoff) to fail against the down server,
    /// then checks the failed player is gone at once, not after the next 4 s
    /// backoff.
    private func assertFailedRetryReleasesPlayer(after previousError: String) async throws {
        try await waitUntil("retry to fail with .failed", timeout: 5) {
            let message = self.player.errorMessage
            return message != nil && message != previousError
        }
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        XCTAssertTrue(player.isReconnecting, "next reconnect should be scheduled")
        XCTAssertFalse(
            player.holdsPlayerResources,
            "failed player, observers and quality timer should be released before the backoff"
        )
    }

    /// The second retry comes 4 s after the failed one.
    private func restartServerAndWaitForResume() async throws {
        try server.start()
        try await waitUntil("playback to resume", timeout: 7) {
            self.player.isPlaying && !self.player.isLoading
                && !self.player.isReconnecting && self.player.errorMessage == nil
        }
        XCTAssertTrue(player.holdsPlayerResources)
    }

    // MARK: - Helpers

    private struct Timeout: Error, CustomStringConvertible {
        let description: String
    }

    private func waitUntil(
        _ what: String,
        timeout: TimeInterval,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                throw Timeout(description: "Timed out after \(timeout)s waiting for \(what)")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Two seconds of silent AAC in ADTS framing, which loops cleanly when
    /// concatenated, like an Icecast AAC stream.
    private static func makeSilentADTS() throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nami-silence-\(UUID().uuidString).aac")
        defer { try? FileManager.default.removeItem(at: url) }
        let sampleRate = 44_100.0
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ])
            let frames = AVAudioFrameCount(sampleRate * LocalStreamServer.audioDuration)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
            buffer.frameLength = frames
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            samples.update(repeating: 0, count: Int(frames))
            try file.write(from: buffer)
        }
        return try Data(contentsOf: url)
    }
}

/// A loopback HTTP server that streams looping audio forever, paced at real
/// time after an initial burst, the way Icecast does. stop() force-cancels the
/// listener and every connection; start() again listens on the same port.
final class LocalStreamServer: @unchecked Sendable {
    static let audioDuration: TimeInterval = 2
    /// AVPlayer reports readyToPlay once about 5 s are buffered.
    private static let burstDuration: TimeInterval = 6
    private static let tickInterval: TimeInterval = 0.25

    private let audio: Data
    private let bytesPerSecond: Int
    private let queue = DispatchQueue(label: "com.nami.tests.stream-server")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var port: NWEndpoint.Port = .any

    init(audio: Data) {
        self.audio = audio
        self.bytesPerSecond = max(1, Int(Double(audio.count) / Self.audioDuration))
    }

    var streamURL: URL {
        URL(string: "http://127.0.0.1:\(queue.sync { port.rawValue })/stream")!
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: queue.sync { port })
        let listener = try NWListener(using: parameters)
        let ready = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: NWError?
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                failure = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 2) == .success else {
            listener.cancel()
            throw NWError.posix(.ETIMEDOUT)
        }
        if let failure {
            listener.cancel()
            throw failure
        }
        queue.sync {
            self.listener = listener
            if let bound = listener.port { port = bound }
        }
    }

    func stop() {
        queue.sync {
            listener?.stateUpdateHandler = nil
            listener?.cancel()
            listener = nil
            connections.values.forEach { $0.forceCancel() }
            connections = [:]
        }
    }

    // Runs on `queue`.
    private func accept(_ connection: NWConnection) {
        connections[ObjectIdentifier(connection)] = connection
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] _, _, _, error in
            guard let self, error == nil else { return }
            let header = "HTTP/1.0 200 OK\r\nContent-Type: audio/aac\r\nCache-Control: no-cache\r\n\r\n"
            connection.send(content: Data(header.utf8), completion: .idempotent)
            self.send(to: connection, from: 0, seconds: Self.burstDuration)
        }
    }

    // Runs on `queue`.
    private func send(to connection: NWConnection, from offset: Int, seconds: TimeInterval) {
        guard connections[ObjectIdentifier(connection)] != nil else { return }
        var chunk = Data()
        var next = offset
        let length = Int(Double(bytesPerSecond) * seconds)
        while chunk.count < length {
            let count = min(length - chunk.count, audio.count - next)
            chunk.append(audio[next..<next + count])
            next = (next + count) % audio.count
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else { return }
            self.queue.asyncAfter(deadline: .now() + Self.tickInterval) {
                self.send(to: connection, from: next, seconds: Self.tickInterval)
            }
        })
    }
}
