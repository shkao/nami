import XCTest
@testable import Nami

@MainActor
final class AppStateTests: XCTestCase {

    func testInitialState() {
        let appState = AppState()

        XCTAssertFalse(appState.isPlaying)
        XCTAssertFalse(appState.isLoading)
        XCTAssertFalse(appState.isReconnecting)
        XCTAssertFalse(appState.isSleepTimerActive)
        XCTAssertNil(appState.sleepTimerEndDate)
        XCTAssertNil(appState.errorMessage)
    }

    func testSleepTimerSetAndCancel() {
        let appState = AppState()

        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: 1, to: Date())!

        appState.setSleepTimer(at: futureTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

        appState.cancelSleepTimer()

        XCTAssertFalse(appState.isSleepTimerActive)
        XCTAssertNil(appState.sleepTimerEndDate)
    }

    func testSleepTimerSchedulesForTomorrowIfTimeHasPassed() {
        let appState = AppState()

        let calendar = Calendar.current
        let pastTime = calendar.date(byAdding: .hour, value: -1, to: Date())!

        appState.setSleepTimer(at: pastTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

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

        appState.togglePlayback()

        appState.togglePlayback()
        XCTAssertFalse(appState.isPlaying)
    }

    func testPlayAndPause() {
        let appState = AppState()

        appState.play()

        appState.pause()
        XCTAssertFalse(appState.isPlaying)
        XCTAssertFalse(appState.isLoading)
    }

    func testCurrentStation() {
        let appState = AppState()

        let initialStation = appState.currentStation
        XCTAssertNotNil(initialStation)

        let newStation = Station.kamakuraFM
        appState.currentStation = newStation
        XCTAssertEqual(appState.currentStation, newStation)
    }

    func testNextStation() {
        let appState = AppState()

        appState.currentStation = Station.allStations[0]
        let firstStation = appState.currentStation

        appState.nextStation()
        XCTAssertNotEqual(appState.currentStation, firstStation)
        XCTAssertEqual(appState.currentStation, Station.allStations[1])
    }

    func testPreviousStation() {
        let appState = AppState()

        appState.currentStation = Station.allStations[1]

        appState.previousStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }

    func testNextStationWrapsAround() {
        let appState = AppState()

        appState.currentStation = Station.allStations.last!

        appState.nextStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }

    func testPreviousStationWrapsAround() {
        let appState = AppState()

        appState.currentStation = Station.allStations[0]

        appState.previousStation()
        XCTAssertEqual(appState.currentStation, Station.allStations.last!)
    }

    func testSignalQuality() {
        let appState = AppState()

        XCTAssertEqual(appState.signalQuality, .none)
    }

    func testSleepTimerReplace() {
        let appState = AppState()
        let calendar = Calendar.current

        let time1 = calendar.date(byAdding: .hour, value: 1, to: Date())!
        appState.setSleepTimer(at: time1)
        let endDate1 = appState.sleepTimerEndDate

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

        let futureTime = calendar.date(byAdding: .minute, value: 30, to: Date())!
        appState.setSleepTimer(at: futureTime)

        XCTAssertTrue(appState.isSleepTimerActive)
        XCTAssertNotNil(appState.sleepTimerEndDate)

        if let endDate = appState.sleepTimerEndDate {
            XCTAssertTrue(endDate > Date())
            let diff = endDate.timeIntervalSinceNow
            XCTAssertGreaterThan(diff, 29 * 60)
            XCTAssertLessThan(diff, 31 * 60)
        }

        appState.cancelSleepTimer()
    }

    func testPlayPauseCycle() {
        let appState = AppState()

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

        appState.currentStation = Station.allStations[0]
        for i in 1..<stationCount {
            appState.nextStation()
            XCTAssertEqual(appState.currentStation, Station.allStations[i])
        }

        appState.nextStation()
        XCTAssertEqual(appState.currentStation, Station.allStations[0])
    }

    func testWakeNotificationDoesNotCrash() {
        let appState = AppState()
        let calendar = Calendar.current

        let futureTime = calendar.date(byAdding: .hour, value: 2, to: Date())!
        appState.setSleepTimer(at: futureTime)

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        XCTAssertTrue(appState.isSleepTimerActive)

        appState.cancelSleepTimer()
    }

    func testWakeNotificationWithNoTimer() {
        let appState = AppState()

        XCTAssertFalse(appState.isSleepTimerActive)

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        XCTAssertFalse(appState.isSleepTimerActive)
    }

    // MARK: - Reconnection Forwarding Tests

    func testIsReconnectingInitiallyFalse() {
        let appState = AppState()
        XCTAssertFalse(appState.isReconnecting)
    }

    func testPauseClearsReconnecting() {
        let appState = AppState()
        appState.play()
        appState.pause()
        XCTAssertFalse(appState.isReconnecting)
    }
}
