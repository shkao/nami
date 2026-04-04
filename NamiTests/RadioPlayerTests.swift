import XCTest
@testable import Nami

@MainActor
final class RadioPlayerTests: XCTestCase {

    func testInitialState() {
        let player = RadioPlayer()

        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        XCTAssertFalse(player.isReconnecting)
        XCTAssertEqual(player.signalQuality, .none)
        XCTAssertNil(player.errorMessage)
    }

    func testDefaultStation() {
        let player = RadioPlayer()

        XCTAssertNotNil(player.currentStation)
        XCTAssertFalse(player.currentStation.id.isEmpty)
    }

    func testVolumeGetterSetter() {
        let player = RadioPlayer()

        player.volume = 0.0
        XCTAssertEqual(player.volume, 0.0, accuracy: 0.01)

        player.volume = 1.0
        XCTAssertEqual(player.volume, 1.0, accuracy: 0.01)

        player.volume = 0.75
        XCTAssertEqual(player.volume, 0.75, accuracy: 0.01)
    }

    func testPlaySetsLoadingState() {
        let player = RadioPlayer()

        player.play()

        XCTAssertTrue(player.isLoading)
        XCTAssertTrue(player.isPlaying)

        player.pause()
    }

    func testPauseResetsState() {
        let player = RadioPlayer()

        player.play()
        player.pause()

        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        XCTAssertFalse(player.isReconnecting)
        XCTAssertEqual(player.signalQuality, .none)
    }

    func testSetStation() {
        let player = RadioPlayer()
        let newStation = Station.kamakuraFM

        player.setStation(newStation)

        XCTAssertEqual(player.currentStation, newStation)
    }

    func testSetStationWhilePlaying() {
        let player = RadioPlayer()

        player.play()
        XCTAssertTrue(player.isPlaying)

        let newStation = Station.chofuFM
        player.setStation(newStation)

        XCTAssertEqual(player.currentStation, newStation)
        XCTAssertTrue(player.isPlaying)

        player.pause()
    }

    func testSetStationWhilePaused() {
        let player = RadioPlayer()

        let newStation = Station.fmSalus
        player.setStation(newStation)

        XCTAssertEqual(player.currentStation, newStation)
        XCTAssertFalse(player.isPlaying)
    }

    func testMultiplePlayPauseCycles() {
        let player = RadioPlayer()

        for _ in 0..<3 {
            player.play()
            XCTAssertTrue(player.isPlaying)

            player.pause()
            XCTAssertFalse(player.isPlaying)
        }
    }

    func testSignalQualityEnum() {
        let qualities: [SignalQuality] = [.excellent, .good, .poor, .none]
        XCTAssertEqual(qualities.count, 4)

        XCTAssertEqual(SignalQuality.excellent, SignalQuality.excellent)
        XCTAssertNotEqual(SignalQuality.excellent, SignalQuality.poor)
    }

    func testPlayAndWaitForStatusChange() {
        let player = RadioPlayer()
        let expectation = XCTestExpectation(description: "Wait for status change")

        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        player.pause()
    }

    func testCleanupAfterMultiplePlays() {
        let player = RadioPlayer()

        player.play()
        player.pause()
        player.play()
        player.pause()

        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.signalQuality, .none)
    }

    func testStationPersistence() {
        let player1 = RadioPlayer()
        let testStation = Station.fmSalus
        player1.setStation(testStation)

        let player2 = RadioPlayer()
        XCTAssertEqual(player2.currentStation, testStation)
    }

    func testPlayWaitsForReadyState() {
        let player = RadioPlayer()
        let expectation = XCTestExpectation(description: "Wait for stream")

        player.play()
        XCTAssertTrue(player.isLoading)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        player.pause()
    }

    func testErrorMessageInitiallyNil() {
        let player = RadioPlayer()
        XCTAssertNil(player.errorMessage)
    }

    func testPlayClearsErrorMessage() {
        let player = RadioPlayer()

        player.play()
        XCTAssertNil(player.errorMessage)

        player.pause()
    }

    func testInitializationUsesSavedStationOrDefaults() {
        let testStation = Station.fmSalus
        UserDefaults.standard.set(testStation.id, forKey: "stationId")

        let player = RadioPlayer()
        XCTAssertEqual(player.currentStation, testStation)

        UserDefaults.standard.removeObject(forKey: "stationId")
    }

    func testInitializationDefaultsToShonanBeachFMWhenNoSavedStation() {
        UserDefaults.standard.removeObject(forKey: "stationId")

        let player = RadioPlayer()
        XCTAssertEqual(player.currentStation, .shonanBeachFM)
    }

    // MARK: - Reconnection Tests

    func testPauseCancelsReconnect() {
        let player = RadioPlayer()

        player.play()
        player.pause()

        XCTAssertFalse(player.isReconnecting)
    }

    func testPlayResetsReconnectState() {
        let player = RadioPlayer()

        player.play()

        // Fresh play should not be in reconnecting state
        XCTAssertFalse(player.isReconnecting)

        player.pause()
    }

    func testHandleWakeWhileNotPlaying() {
        let player = RadioPlayer()

        // Should not crash or start playing
        player.handleWake()

        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isReconnecting)
    }

    func testHandleWakeWhilePlaying() {
        let player = RadioPlayer()

        player.play()
        XCTAssertTrue(player.isPlaying)

        player.handleWake()

        // Should be attempting to reconnect
        XCTAssertTrue(player.isPlaying)

        player.pause()
    }
}
