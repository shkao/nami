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
}
