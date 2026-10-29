import Foundation
@main struct PlaybackTests {
    static func main() async throws {
        let engineRoot = CommandLine.arguments[1]
        setenv("VLC_PLUGIN_PATH",engineRoot+"/plugins",1)
        let relay = StreamRelay(); try relay.start()
        let route = Route()
        let data = try route.fetch(URL(string:"https://de1.api.radio-browser.info/json/stations/search?name=MANGORADIO&limit=1&hidebroken=true")!)
        let rows = try JSONSerialization.jsonObject(with:data) as! [[String:Any]]
        guard let row = rows.first else { fatalError("No radio result") }
        let station = Station.from(row)
        let recording = FileManager.default.temporaryDirectory.appendingPathComponent("deutsia-playback-test.ts")
        try? FileManager.default.removeItem(at:recording)
        let player = try Player()
        try player.play(relay.local(try validateStream(station.streamUrl),route:route),volume:0,recording:recording)
        var played = false
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds:500_000_000)
            if player.state == 3 { played = true }
            if player.state == 7 { break }
        }
        let state = player.state
        player.stop(); relay.reset()
        let size = (try? FileManager.default.attributesOfItem(atPath:recording.path)[.size] as? Int) ?? 0
        guard played && size > 4096 else { fatalError("Playback/recording failed: state=\(state), bytes=\(size)") }
        print("PASS: online directory, relayed playback, recording (\(size) bytes), clean stop")
    }
}
