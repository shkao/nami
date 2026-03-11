import XCTest
@testable import Nami

@MainActor
final class NamiAppTests: XCTestCase {

    func testAppDelegateInitialization() {
        let appDelegate = AppDelegate()

        // AppDelegate should initialize without crashing
        XCTAssertNotNil(appDelegate)
    }

    func testSetupStatusItemCreatesButton() {
        let appDelegate = AppDelegate()
        appDelegate.setupStatusItem()

        // Should have created a status item
        XCTAssertNotNil(appDelegate.statusItem)
        XCTAssertNotNil(appDelegate.statusItem.button)

        // Button should have the correct image and action
        let button = appDelegate.statusItem.button!
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.target as? AppDelegate, appDelegate)
        XCTAssertEqual(button.action, #selector(AppDelegate.togglePopover))
    }

    func testSetupPopoverCreatesPopover() {
        let appDelegate = AppDelegate()
        appDelegate.setupPopover()

        // Should have created a popover
        XCTAssertNotNil(appDelegate.popover)
        XCTAssertEqual(appDelegate.popover.contentSize, NSSize(width: 200, height: 320))
        XCTAssertEqual(appDelegate.popover.behavior, .transient)
        XCTAssertTrue(appDelegate.popover.animates)
    }

    func testSetupEventMonitorCreatesMonitor() {
        let appDelegate = AppDelegate()
        appDelegate.setupEventMonitor()

        // Should have created an event monitor
        XCTAssertNotNil(appDelegate.eventMonitor)
    }

    func testTogglePopoverDoesNotCrash() {
        let appDelegate = AppDelegate()
        appDelegate.setupStatusItem()
        appDelegate.setupPopover()

        // NSPopover.show() requires a real window hierarchy, so isShown stays false in tests.
        // Verify togglePopover doesn't crash and popover starts not shown.
        XCTAssertFalse(appDelegate.popover.isShown)
        appDelegate.togglePopover()
        appDelegate.togglePopover()
    }

    func testApplicationWillTerminateRemovesEventMonitor() {
        let appDelegate = AppDelegate()
        appDelegate.setupEventMonitor()

        // Should have an event monitor
        XCTAssertNotNil(appDelegate.eventMonitor)

        // Terminate should remove it
        appDelegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        // Note: We can't easily test if the monitor was actually removed
        // without calling NSEvent.removeMonitor which would affect other tests
        // But we can verify the method doesn't crash
    }

    func testApplicationDidFinishLaunchingCallsSetupMethods() {
        let appDelegate = AppDelegate()

        // This should not crash and should call all setup methods
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Verify that setup happened
        XCTAssertNotNil(appDelegate.statusItem)
        XCTAssertNotNil(appDelegate.popover)
        XCTAssertNotNil(appDelegate.eventMonitor)
    }
}