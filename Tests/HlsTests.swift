import Foundation
import Network
@main struct HlsTests {
    static func main() async throws {
        let root = CommandLine.arguments[1]; setenv("VLC_PLUGIN_PATH",root+"/plugins",1)
        let audio = try Data(contentsOf:FileManager.default.temporaryDirectory.appendingPathComponent("deutsia-playback-test.ts"))
        let listener = try NWListener(using:.tcp,on:.any), ready = DispatchSemaphore(value:0)
        listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        listener.newConnectionHandler = { c in
            c.start(queue:.global()); c.receive(minimumIncompleteLength:1,maximumLength:8192) { bytes,_,_,_ in
                let request = String(decoding:bytes ?? Data(),as:UTF8.self)
                let body: Data, mime: String
                if request.contains("/master.m3u8") { body = Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=128000\nvariant/list.m3u8\n".utf8); mime = "application/vnd.apple.mpegurl" }
                else if request.contains("/variant/list.m3u8") { body = Data("#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:30\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:25,\n../segment.ts\n#EXT-X-ENDLIST\n".utf8); mime = "application/vnd.apple.mpegurl" }
                else { body = audio; mime = "video/mp2t" }
                let response = Data("HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)+body
                c.send(content:response,completion:.contentProcessed { _ in c.cancel() })
            }
        }
        listener.start(queue:.global()); guard ready.wait(timeout:.now()+5) == .success else { fatalError("origin server failed") }
        let relay = StreamRelay(); try relay.start()
        let player = try Player()
        let url = URL(string:"http://127.0.0.1:\(listener.port!.rawValue)/master.m3u8")!
        try player.play(relay.local(url,route:Route()),volume:0)
        var played = false
        for _ in 0..<16 { try await Task.sleep(nanoseconds:500_000_000); if player.state == 3 { played = true; break }; if player.state == 7 { break } }
        let state = player.state; player.stop(); relay.reset(); listener.cancel()
        guard played else { fatalError("HLS playback failed: \(state)") }
        print("PASS: HLS master → relative variant → relative segment → audio playback")
    }
}
