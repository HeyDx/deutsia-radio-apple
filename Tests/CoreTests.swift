import Foundation
import CryptoKit
@main struct CoreTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws { guard condition() else { throw RadioError.message(message) }; count += 1 }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("deutsia-tests-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        var keyRequests = 0
        let lazyVault = try Vault(folder:root.appendingPathComponent("plain"),keyProvider:{ keyRequests += 1; throw RadioError.message("Test key access") })
        try lazyVault.save(Library())
        let plain = try lazyVault.load()
        try expect(plain.stations.isEmpty && keyRequests == 0,"unencrypted library never requests Keychain")
        var encrypted = Library(); encrypted.preferences.encrypted = true
        do { try lazyVault.save(encrypted); throw RadioError.message("missing key accepted") } catch RadioError.message(let message) { try expect(message == "Test key access" && keyRequests == 1,"encrypted library requests key only when needed") }
        let vault = try Vault(folder:root,key:SymmetricKey(size:.bits256))
        var lib = Library(); var station = Station(); station.name = "Test, \"radio\"\n二"; station.streamUrl = "https://example.com/stream"; station.genre = "Jazz"; station.isLiked = true
        lib.stations = [station]; lib.preferences.encrypted = true
        try vault.save(lib)
        let raw = try Data(contentsOf:root.appendingPathComponent("library.dat"))
        try expect(raw.starts(with:Data("DRM1".utf8)),"encrypted marker")
        try expect(!String(decoding:raw,as:UTF8.self).contains(station.streamUrl),"plaintext disclosure")
        let loaded = try vault.load(); try expect(loaded.stations == lib.stations,"encrypted roundtrip")
        var tampered = raw; tampered[tampered.count-1] ^= 1
        try tampered.write(to:root.appendingPathComponent("library.dat"))
        do { _ = try vault.load(); throw RadioError.message("tamper accepted") } catch is CryptoKitError { count += 1 }
        for ext in ["json","csv","m3u","pls"] {
            var s = station
            if ["m3u","pls"].contains(ext) { s.name = "Test Radio" }
            let result = try importStations(exportStations([s],ext:ext),ext:ext)
            try expect(result.first?.streamUrl == s.streamUrl,"\(ext) stream roundtrip")
            try expect(result.first?.name == s.name,"\(ext) name roundtrip")
            if ext == "json" || ext == "csv" { try expect(result.first?.isLiked == true,"\(ext) favorite") }
        }
        for bad in ["file:///etc/passwd","https://station.onion/live","ftp://example.com","not-a-url"] { do { _ = try validateStream(bad); throw RadioError.message("bad URL allowed") } catch RadioError.message(let m) { try expect(m != "bad URL allowed","reject \(bad)") } }
        let rewritten = rewritePlaylist("#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"key.bin\"\n../part.ts\nhttps://other.example/x.ts",base:URL(string:"https://example.com/a/live.m3u8")!) { "relay:"+$0.absoluteString }
        try expect(rewritten.contains("relay:https://example.com/a/key.bin"),"HLS key route")
        try expect(rewritten.contains("relay:https://example.com/part.ts"),"HLS relative route")
        try expect(rewritten.contains("relay:https://other.example/x.ts"),"HLS absolute route")
        let dash = "<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\"><Period><AdaptationSet><BaseURL>audio/</BaseURL><SegmentTemplate media=\"$RepresentationID$/seg-$Number$.m4s?token=a&amp;x=1\" initialization=\"init.mp4\"/><Representation id=\"aac\"/></AdaptationSet></Period></MPD>"
        let mapped = try rewriteDASH(dash,base:URL(string:"https://example.com/live/main.mpd")!) { "http://127.0.0.1:9999/" + ($0.path.hasPrefix("/") ? String($0.path.dropFirst()) : $0.path) + ($0.query.map { "?"+$0 } ?? "") }
        try expect(mapped.contains("live/audio/$RepresentationID$/seg-$Number$.m4s?token=a&amp;x=1"),"DASH template and query")
        try expect(mapped.contains("live/audio/init.mp4"),"DASH initialization")
        do { _ = try rewriteDASH("<MPD><BaseURL>http://bad.onion/</BaseURL></MPD>",base:URL(string:"https://example.com/main.mpd")!) { $0.absoluteString }; throw RadioError.message("DASH onion allowed") } catch RadioError.message(let m) { try expect(m != "DASH onion allowed","DASH Tor rejection") }
        var prefs = Preferences(); prefs.forceProxy = true; prefs.proxyProtocol = "SOCKS5"; prefs.proxyHost = "127.0.0.1"; prefs.proxyPort = 1
        let route = try Route.make(station:nil,prefs:prefs)
        try expect(route.proxy == "socks5h://127.0.0.1:1","SOCKS5 remote DNS")
        do { _ = try route.fetch(URL(string:"http://127.0.0.1:9")!); throw RadioError.message("proxy fallback") } catch RadioError.message(let m) { try expect(m != "proxy fallback","fail closed") }
        station.streamUrl = "http://test.i2p/live"; let i2p = try Route.make(station:station,prefs:prefs)
        try expect(i2p.proxy == "http://127.0.0.1:4444","I2P separate routing")
        try expect(stationLanguageTerms("@chinese").contains("cantonese"),"Chinese includes Cantonese")
        try expect(stationLanguageTerms("@mandarin").contains("chinese"),"Mandarin includes generic Chinese tags")
        let filterURLs = stationSearchURLs(base:URL(string:"https://example.com/search?country=China&tag=jazz")!,language:"@cantonese",i2p:false)
        try expect(filterURLs.count == 3,"Cantonese aliases")
        try expect(filterURLs.allSatisfy { URLComponents(url:$0,resolvingAgainstBaseURL:true)!.queryItems!.contains(URLQueryItem(name:"country",value:"China")) },"combined country/language filters")
        let a = pinDigest("123456",salt:"test-salt"), b = pinDigest("123456",salt:"different-salt")
        try expect(!a.isEmpty && a != b,"PIN salt")
        NetworkPolicy.shared.cancelAll()
        do { _ = try route.fetch(URL(string:"http://127.0.0.1:9")!); throw RadioError.message("old generation allowed") } catch RadioError.message(let m) { try expect(m != "old generation allowed","outdated route blocked") }
        print("PASS: \(count) core checks")
    }
}
