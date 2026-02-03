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
}
