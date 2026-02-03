import XCTest
@testable import Nami

final class AppStateTests: XCTestCase {

    func testInitialState() {
        let appState = AppState()

        XCTAssertFalse(appState.isPlaying)
        XCTAssertFalse(appState.isLoading)
        XCTAssertFalse(appState.isSleepTimerActive)
        XCTAssertNil(appState.sleepTimerEndDate)
        XCTAssertNil(appState.errorMessage)
    }

    func testSleepTimerSetAndCancel() {
        let appState = AppState()

        // Set sleep timer for 1 hour from now
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: 1, to: Date())!

        appState.setSleepTimer(at: futureTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

        // Cancel the timer
        appState.cancelSleepTimer()

        XCTAssertFalse(appState.isSleepTimerActive)
        XCTAssertNil(appState.sleepTimerEndDate)
    }

    func testSleepTimerSchedulesForTomorrowIfTimeHasPassed() {
        let appState = AppState()

        // Set a time that has already passed today (1 hour ago)
        let calendar = Calendar.current
        let pastTime = calendar.date(byAdding: .hour, value: -1, to: Date())!

        appState.setSleepTimer(at: pastTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

        // The scheduled time should be in the future (tomorrow)
        if let endDate = appState.sleepTimerEndDate {
            XCTAssertTrue(endDate > Date())
        }

        appState.cancelSleepTimer()
    }

    func testVolumeRange() {
        let appState = AppState()

        appState.volume = 0.0
        XCTAssertEqual(appState.volume, 0.0, accuracy: 0.01)

        appState.volume = 1.0
        XCTAssertEqual(appState.volume, 1.0, accuracy: 0.01)

        appState.volume = 0.5
        XCTAssertEqual(appState.volume, 0.5, accuracy: 0.01)
    }

    func testTogglePlayback() {
        let appState = AppState()

        XCTAssertFalse(appState.isPlaying)

        // Toggle should attempt to play (may not actually play without network)
        appState.togglePlayback()
        // Can't assert isPlaying true because it depends on network/stream

        // Toggle again should pause
        appState.togglePlayback()
        XCTAssertFalse(appState.isPlaying)
    }

    func testPlayAndPause() {
        let appState = AppState()

        appState.play()
        // Play initiates loading, actual playback depends on network

        appState.pause()
        XCTAssertFalse(appState.isPlaying)
        XCTAssertFalse(appState.isLoading)
    }

    func testCurrentStation() {
        let appState = AppState()

        // Get current station
        let initialStation = appState.currentStation
        XCTAssertNotNil(initialStation)

        // Set a different station
        let newStation = Station.kamakuraFM
        appState.currentStation = newStation
        XCTAssertEqual(appState.currentStation, newStation)
    }

    func testNextStation() {
        let appState = AppState()

        // Set to first station
        appState.currentStation = Station.allStations[0]
        let firstStation = appState.currentStation

        // Go to next
        appState.nextStation()
        XCTAssertNotEqual(appState.currentStation, firstStation)
        XCTAssertEqual(appState.currentStation, Station.allStations[1])
    }

    func testPreviousStation() {
        let appState = AppState()

        // Set to second station
        appState.currentStation = Station.allStations[1]

        // Go to previous
        appState.previousStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }

    func testNextStationWrapsAround() {
        let appState = AppState()

        // Set to last station
        appState.currentStation = Station.allStations.last!

        // Go to next should wrap to first
        appState.nextStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }

    func testPreviousStationWrapsAround() {
        let appState = AppState()

        // Set to first station
        appState.currentStation = Station.allStations[0]

        // Go to previous should wrap to last
        appState.previousStation()
        XCTAssertEqual(appState.currentStation, Station.allStations.last!)
    }

    func testSignalQuality() {
        let appState = AppState()

        // When not playing, signal quality should be none
        XCTAssertEqual(appState.signalQuality, .none)
    }

    func testSleepTimerReplace() {
        let appState = AppState()
        let calendar = Calendar.current

        // Set first timer
        let time1 = calendar.date(byAdding: .hour, value: 1, to: Date())!
        appState.setSleepTimer(at: time1)
        let endDate1 = appState.sleepTimerEndDate

        // Set second timer - should replace the first
        let time2 = calendar.date(byAdding: .hour, value: 2, to: Date())!
        appState.setSleepTimer(at: time2)
        let endDate2 = appState.sleepTimerEndDate

        XCTAssertNotEqual(endDate1, endDate2)
        XCTAssertTrue(appState.isSleepTimerActive)

        appState.cancelSleepTimer()
    }

    func testSleepTimerEndDateIsInFuture() {
        let appState = AppState()
        let calendar = Calendar.current

        // Set timer for 30 minutes from now
        let futureTime = calendar.date(byAdding: .minute, value: 30, to: Date())!
        appState.setSleepTimer(at: futureTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

        if let endDate = appState.sleepTimerEndDate {
            XCTAssertTrue(endDate > Date())
            // Should be approximately 30 minutes from now
            let diff = endDate.timeIntervalSinceNow
            XCTAssertGreaterThan(diff, 29 * 60)
            XCTAssertLessThan(diff, 31 * 60)
        }

        appState.cancelSleepTimer()
    }

    func testPlayPauseCycle() {
        let appState = AppState()

        // Multiple cycles
        for _ in 0..<3 {
            appState.play()
            appState.pause()
        }

        XCTAssertFalse(appState.isPlaying)
        XCTAssertFalse(appState.isLoading)
    }

    func testStationCycleThrough() {
        let appState = AppState()
        let stationCount = Station.allStations.count

        // Cycle through all stations using next
        appState.currentStation = Station.allStations[0]
        for i in 1..<stationCount {
            appState.nextStation()
            XCTAssertEqual(appState.currentStation, Station.allStations[i])
        }

        // One more should wrap to first
        appState.nextStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }
}
