import XCTest
@testable import Nami

final class StationTests: XCTestCase {

    func testAllStationsExist() {
        XCTAssertEqual(Station.allStations.count, 5)
    }

    func testStationIdentifiable() {
        let station = Station.shonanBeachFM
        XCTAssertFalse(station.id.isEmpty)
    }

    func testStationEquatable() {
        let station1 = Station.shonanBeachFM
        let station2 = Station.shonanBeachFM
        let station3 = Station.kamakuraFM

        XCTAssertEqual(station1, station2)
        XCTAssertNotEqual(station1, station3)
    }

    func testIsFrequencyNumeric() {
        // All current stations have numeric frequencies
        for station in Station.allStations {
            XCTAssertTrue(station.isFrequencyNumeric, "\(station.name) should have numeric frequency")
        }
    }

    func testStationStreamURLValid() {
        for station in Station.allStations {
            XCTAssertNotNil(station.streamURL.scheme)
            XCTAssertTrue(station.streamURL.absoluteString.hasPrefix("http"))
        }
    }

    func testStationFrequencies() {
        XCTAssertEqual(Station.fmBlueShonan.frequency, "78.5")
        XCTAssertEqual(Station.shonanBeachFM.frequency, "78.9")
        XCTAssertEqual(Station.kamakuraFM.frequency, "82.8")
        XCTAssertEqual(Station.chofuFM.frequency, "83.8")
        XCTAssertEqual(Station.fmSalus.frequency, "84.1")
    }

    func testStationsAreSortedByFrequency() {
        let stations = Station.allStations
        for i in 0..<(stations.count - 1) {
            let freq1 = Double(stations[i].frequency) ?? 0
            let freq2 = Double(stations[i + 1].frequency) ?? 0
            XCTAssertLessThan(freq1, freq2, "Stations should be sorted by frequency")
        }
    }
}
