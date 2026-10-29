import SwiftUI
import MediaPlayer
import LocalAuthentication
#if os(iOS)
import AVFoundation
import UIKit
#endif
@MainActor final class RadioStore: ObservableObject {
    @Published var library = Library()
    @Published var results: [Station] = []
    @Published var section = "discover"
    @Published var query = ""
    @Published var country = ""
    @Published var stationLanguage = ""
    @Published var stationLanguages = ["english","japanese","korean","french","german","spanish","russian","portuguese","arabic"]
    @Published var loadingLanguages = false
    private var languagesLoaded = false
    @Published var countries: [String] = []
    @Published var loadingCountries = false
    private var searchID = UUID()
    @Published var tag = ""
    @Published var status = "准备好，发现下一段好声音"
    @Published var current: Station?
    @Published var playing = false
    @Published var busy = false
    @Published var error: String?
    @Published var locked = false
    @Published var recordingURL: URL?
    @Published var recordingPlayers: [String:Player] = [:]
    @Published var timerEnd: Date?
    @Published var track = ""
    @Published var eqEnabled = false
    @Published var bands = [Double](repeating: 0, count: 10)
    var vault: Vault?
    var engine: Player?
    let relay = StreamRelay()
    var timer: Timer?
    var failures = 0
    init() {
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            vault = try Vault(); library = try vault!.load(); locked = !library.preferences.pinHash.isEmpty
            try relay.start(); engine = try Player()
        } catch { self.error = error.localizedDescription }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        remote.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        remote.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        remote.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(1) }; return .success }
        remote.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(-1) }; return .success }
    }
    var accent: Color {
        switch library.preferences.accent { case "blue": return .blue; case "green": return .green; case "orange": return .orange; case "pink": return .pink; case "teal": return .teal; default: return .purple }
    }
    var networkFingerprint: String {
        let p = library.preferences
        return "\(p.forceProxy)|\(p.proxyHost)|\(p.proxyPort)|\(p.proxyProtocol)|\(p.proxyUsername)|\(p.proxyPassword)|\(p.proxyAuthType)|\(p.i2pHost)|\(p.i2pPort)"
    }
    func renameGenre(_ old: String, to new: String) {
        let value = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        for i in library.stations.indices where library.stations[i].genre == old { library.stations[i].genre = value }
        for i in library.queue.indices where library.queue[i].genre == old { library.queue[i].genre = value }
        save()
    }
    func save() { do { try vault?.save(library) } catch { self.error = error.localizedDescription } }
    func add(_ station: Station) { if !library.stations.contains(where: { $0.streamUrl == station.streamUrl }) { library.stations.append(station); save() } }
    func update(_ s: Station) { if let i = library.stations.firstIndex(where: { $0.id == s.id }) { library.stations[i] = s } else { add(s) }; save() }
    func favorite(_ station: Station) { add(station); if let i = library.stations.firstIndex(where: { $0.streamUrl == station.streamUrl }) { library.stations[i].isLiked.toggle() }; save() }
    func enqueue(_ s: Station) { library.queue.append(s); save() }
    func remove(_ s: Station) { library.stations.removeAll { $0.id == s.id }; save() }
    func play(_ s: Station) {
        do {
            let u = try validateStream(s.streamUrl), route = try Route.make(station: s, prefs: library.preferences)
            if library.preferences.recordAcrossStations {
                if recordingURL != nil, let old = current, let oldEngine = engine {
                    oldEngine.volume(0); recordingPlayers[old.id]?.stop(); recordingPlayers[old.id] = oldEngine; engine = try Player()
                } else { engine?.stop() }
            } else { engine?.stop(); relay.reset(); stopOtherRecordings() }
            recordingURL = nil
            try engine?.play(relay.local(u, route: route), volume: library.preferences.volume)
            current = s; playing = true; failures = 0; track = ""; status = "正在连接 · \(s.network)"
            var item = s; item.lastPlayedAt = Date().timeIntervalSince1970
            library.history.removeAll { $0.streamUrl == s.streamUrl }; library.history.insert(item, at: 0); library.history = Array(library.history.prefix(200))
            save(); applyEQ(); nowPlaying()
        } catch { self.error = error.localizedDescription }
    }
    func toggle() { playing ? pause() : resume() }
    func pause() { engine?.pause(true); playing = false; status = "已暂停"; nowPlaying() }
    func resume() { if current == nil, let s = library.queue.first ?? library.stations.first { play(s) } else { engine?.pause(false); playing = true; nowPlaying() } }
    func stop() { engine?.stop(); stopOtherRecordings(); relay.reset(); playing = false; recordingURL = nil; status = "播放已停止"; nowPlaying() }
    func skip(_ offset: Int) {
        let list = library.queue.isEmpty ? library.stations : library.queue
        guard !list.isEmpty else { return }
        let index = current.flatMap { s in list.firstIndex(where: { $0.streamUrl == s.streamUrl }) } ?? 0
        play(list[(index + offset + list.count) % list.count])
    }
    func volumeChanged() { engine?.volume(library.preferences.volume); save() }
    func applyEQ() { engine?.equalizer(bands, enabled: eqEnabled) }
    func nowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: track.isEmpty ? current?.name ?? "Deutsia Radio" : track, MPMediaItemPropertyArtist: current?.name ?? "", MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: playing ? 1 : 0]
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }
    func tick() {
        if let end = timerEnd, Date() >= end { stop(); timerEnd = nil }
        guard playing, let engine else { return }
        switch engine.state {
        case 3: status = recordingURL == nil ? "正在播放 · \(current?.network ?? "")" : "正在播放并录音"; failures = 0
        case 7: status = "连接失败，请检查电台地址或代理"; playing = false; error = status
        case 6: status = "音频流已结束"; playing = false
        default: break
        }
        let title = engine.title
        if title != track { track = title; nowPlaying() }
    }
    func settingsChanged() { searchID = UUID(); busy = false; NetworkPolicy.shared.cancelAll(); stop(); save() }
    func recordCurrent() {
        guard let s = current else { return }
        if recordingURL != nil { engine?.stop(); recordingURL = nil; play(s); return }
        #if os(macOS)
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(s.name.replacingOccurrences(of: "/", with: "-"))-\(Int(Date().timeIntervalSince1970)).ts"
        guard panel.runModal() == .OK, let u = panel.url else { return }
        #else
        let u = recordingPath(s)
        #endif
        do {
            engine?.stop()
            let route = try Route.make(station: s, prefs: library.preferences)
            try engine?.play(relay.local(try validateStream(s.streamUrl), route: route), volume: library.preferences.volume, recording: u)
            recordingURL = u; playing = true; applyEQ()
        } catch { self.error = error.localizedDescription }
    }
    func recordStation(_ s: Station) {
        if let p = recordingPlayers.removeValue(forKey: s.id) { p.stop(); return }
        #if os(macOS)
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(s.name.replacingOccurrences(of: "/", with: "-"))-\(Int(Date().timeIntervalSince1970)).ts"
        guard panel.runModal() == .OK, let u = panel.url else { return }
        #else
        let u = recordingPath(s)
        #endif
        do { let p = try Player(); try p.play(relay.local(try validateStream(s.streamUrl), route: Route.make(station: s, prefs: library.preferences)), volume: 0, recording: u); recordingPlayers[s.id] = p }
        catch { self.error = error.localizedDescription }
    }
    func stopOtherRecordings() { recordingPlayers.values.forEach { $0.stop() }; recordingPlayers.removeAll() }
    func loadStationLanguages() {
        guard !loadingLanguages, !languagesLoaded, library.preferences.radioBrowser else { return }
        loadingLanguages = true
        let prefs = library.preferences
        Task {
            defer { loadingLanguages = false }
            do {
                let route = try Route.make(station:nil,prefs:prefs)
                let names: [String] = try await Task.detached {
                    let url = URL(string:"https://de1.api.radio-browser.info/json/languages?order=stationcount&reverse=true&limit=150&hidebroken=true")!
                    #if os(iOS)
                    let data = try await route.fetch(url)
                    #else
                    let data = try route.fetch(url)
                    #endif
                    let rows = try JSONSerialization.jsonObject(with:data) as? [[String:Any]] ?? []
                    return rows.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }.sorted()
                }.value
                stationLanguages = names; languagesLoaded = true
            } catch { status = "语言选单暂未更新，已保留常用语言" }
        }
    }
    func loadCountries() {
        guard !loadingCountries, countries.isEmpty, library.preferences.radioBrowser else { return }
        loadingCountries = true
        let prefs = library.preferences
        Task {
            defer { loadingCountries = false }
            do {
                let route = try Route.make(station:nil,prefs:prefs)
                let items: [String] = try await Task.detached {
                    let url = URL(string:"https://de1.api.radio-browser.info/json/countries")!
                    #if os(iOS)
                    let data = try await route.fetch(url)
                    #else
                    let data = try route.fetch(url)
                    #endif
                    let rows = try JSONSerialization.jsonObject(with:data) as? [[String:Any]] ?? []
                    return rows.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }.sorted()
                }.value
                countries = items
            } catch { status = "国家选单加载失败，可稍后重试" }
        }
    }
    func search(i2p: Bool = false, order: String = "votes") {
        let prefs = library.preferences
        guard i2p ? prefs.registry : prefs.radioBrowser else { error = "此电台目录已在设置中关闭"; return }
        busy = true
        let requestID = UUID(); searchID = requestID
        var components = URLComponents(string: i2p ? "https://api.deutsia.com/api/stations" : "https://de1.api.radio-browser.info/json/stations/search")!
        components.queryItems = i2p ? [URLQueryItem(name:"network", value:"i2p"),URLQueryItem(name:"limit",value:"200")] : [URLQueryItem(name:"name",value:query),URLQueryItem(name:"country",value:country),URLQueryItem(name:"tag",value:tag),URLQueryItem(name:"limit",value:"120"),URLQueryItem(name:"hidebroken",value:"true"),URLQueryItem(name:"order",value:order),URLQueryItem(name:"reverse",value:"true")]
        let urls = stationSearchURLs(base:components.url!,language:stationLanguage,i2p:i2p), q = query
        Task {
            do {
                let route = try Route.make(station: nil, prefs: prefs)
                let items: [Station] = try await Task.detached {
                    var stations: [Station] = [], seen = Set<String>(), lastError: Error?, succeeded = false
                    for url in urls {
                        do {
                            #if os(iOS)
                            let data = try await route.fetch(url)
                            #else
                            let data = try route.fetch(url)
                            #endif
                            let root = try JSONSerialization.jsonObject(with:data)
                            let rows = root as? [[String:Any]] ?? (root as? [String:Any])?["stations"] as? [[String:Any]] ?? []
                            succeeded = true
                            for station in rows.map(Station.from) where (try? validateStream(station.streamUrl)) != nil && (!i2p || station.network == "I2P") && (!i2p || q.isEmpty || station.name.localizedCaseInsensitiveContains(q)) {
                                if seen.insert(station.streamUrl).inserted { stations.append(station) }
                            }
                        } catch { lastError = error }
                    }
                    if !succeeded, let lastError { throw lastError }
                    return stations
                }.value
                guard requestID == searchID else { return }
                results = items; status = "找到 \(items.count) 个电台"; busy = false
            } catch { guard requestID == searchID else { return }; self.error = error.localizedDescription; busy = false }
        }
    }
    #if os(macOS)
    func importFile() {
        let p = NSOpenPanel(); p.allowsMultipleSelection = false; p.allowedContentTypes = [.json,.commaSeparatedText,.plainText,.data]
        guard p.runModal() == .OK, let u = p.url else { return }
        do { let list = try importStations(Data(contentsOf: u), ext: u.pathExtension.lowercased()); list.forEach(add); status = "已导入 \(list.count) 个电台" }
        catch { self.error = error.localizedDescription }
    }
    func exportFile(_ ext: String) {
        let p = NSSavePanel(); p.nameFieldStringValue = "deutsia-stations.\(ext)"
        guard p.runModal() == .OK, let u = p.url else { return }
        do { try exportStations(library.stations, ext: ext).write(to: u, options: .atomic) } catch { self.error = error.localizedDescription }
    }
    #else
    func recordingPath(_ s: Station) -> URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(s.name.replacingOccurrences(of: "/", with: "-"))-\(Int(Date().timeIntervalSince1970)).ts")
    }
    func importData(_ data: Data, ext: String) {
        do { let items = try importStations(data, ext: ext); items.forEach(add); status = "已导入 \(items.count) 个电台" } catch { self.error = error.localizedDescription }
    }
    #endif
    func setPIN(_ value: String) {
        guard value.count >= 6 else { error = "PIN 至少需要 6 位"; return }
        let salt = UUID().uuidString; library.preferences.pinSalt = salt; library.preferences.pinHash = pinDigest(value, salt: salt); save()
    }
    func unlock(_ pin: String) { if pinDigest(pin, salt: library.preferences.pinSalt) == library.preferences.pinHash { locked = false } else { error = "PIN 不正确" } }
    func biometricUnlock() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 Deutsia Radio") { success, _ in Task { @MainActor in if success { self.locked = false } else { self.error = "生物识别未通过，请使用 PIN" } } }
    }
}
