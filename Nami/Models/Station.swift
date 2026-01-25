import Foundation

struct Station: Identifiable, Equatable {
    let id: String
    let name: String
    let frequency: String
    let streamURL: URL

    var isFrequencyNumeric: Bool {
        Double(frequency) != nil
    }

    static let fmBlueShonan = Station(
        id: "blue-shonan",
        name: "FM Blue Shonan",
        frequency: "78.5",
        streamURL: URL(string: "https://mtist.as.smartstream.ne.jp/30019/livestream/playlist.m3u8")!
    )

    static let shonanBeachFM = Station(
        id: "shonan",
        name: "Shonan Beach FM",
        frequency: "78.9",
        streamURL: URL(string: "https://shonanbeachfm.out.airtime.pro/shonanbeachfm_c")!
    )

    static let kamakuraFM = Station(
        id: "kamakura",
        name: "Kamakura FM",
        frequency: "82.8",
        streamURL: URL(string: "https://mtist.as.smartstream.ne.jp/30037/livestream/playlist.m3u8")!
    )

    static let chofuFM = Station(
        id: "chofu",
        name: "Chofu FM",
        frequency: "83.8",
        streamURL: URL(string: "https://mtist.as.smartstream.ne.jp/30039/livestream/playlist.m3u8")!
    )

    static let fmSalus = Station(
        id: "salus",
        name: "FM Salus",
        frequency: "84.1",
        streamURL: URL(string: "https://mtist.as.smartstream.ne.jp/30048/livestream/playlist.m3u8")!
    )

    // Sorted by frequency: 78.5, 78.9, 82.8, 83.8, 84.1
    static let allStations: [Station] = [.fmBlueShonan, .shonanBeachFM, .kamakuraFM, .chofuFM, .fmSalus]
}
