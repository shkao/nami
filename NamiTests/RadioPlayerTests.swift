import XCTest
@testable import Nami

final class RadioPlayerTests: XCTestCase {

    func testInitialState() {
        let player = RadioPlayer()

        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        XCTAssertEqual(player.signalQuality, .none)
        XCTAssertNil(player.errorMessage)
    }

    func testDefaultStation() {
        let player = RadioPlayer()

        // Should have a valid station
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

        // Play should set loading to true initially
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

        // Change station while playing
        let newStation = Station.chofuFM
        player.setStation(newStation)

        // Should still be playing with new station
        XCTAssertEqual(player.currentStation, newStation)
        XCTAssertTrue(player.isPlaying)

        player.pause()
    }

    func testSetStationWhilePaused() {
        let player = RadioPlayer()

        // Change station while paused
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
        // Test all signal quality cases exist
        let qualities: [SignalQuality] = [.excellent, .good, .poor, .none]
        XCTAssertEqual(qualities.count, 4)
    }

    func testPlayAndWaitForStatusChange() {
        let player = RadioPlayer()
        let expectation = XCTestExpectation(description: "Wait for status change")

        player.play()

        // Wait briefly for KVO observers to potentially fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Player should still be in some state
            // The callbacks may or may not have fired depending on network
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        player.pause()
    }

    func testCleanupAfterMultiplePlays() {
        let player = RadioPlayer()

        // Multiple play/pause cycles should clean up properly
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

        // Create new player - should restore saved station
        let player2 = RadioPlayer()
        XCTAssertEqual(player2.currentStation, testStation)
    }
}
