import Foundation
import Network
struct Route {
    var generation = NetworkPolicy.shared.generation
    var proxy: String? = nil
    var username = ""
    var password = ""
    var auth = "NONE"
    static func make(station: Station?, prefs: Preferences) throws -> Route {
        if let s = station, s.network == "I2P" || s.proxyType == "I2P" {
            return Route(proxy: "http://\(prefs.i2pHost):\(prefs.i2pPort)")
        }
        if let s = station, s.proxyType == "CUSTOM" {
            return try configured(s.customProxyProtocol, s.proxyHost, s.proxyPort, s.proxyUsername, s.proxyPassword, s.proxyAuthType)
        }
        if prefs.forceProxy { return try configured(prefs.proxyProtocol, prefs.proxyHost, prefs.proxyPort, prefs.proxyUsername, prefs.proxyPassword, prefs.proxyAuthType) }
        return Route()
    }
    static func configured(_ proto: String, _ host: String, _ port: Int, _ user: String, _ pass: String, _ auth: String) throws -> Route {
        guard !host.isEmpty, (1...65535).contains(port), !host.contains("/"), !host.contains("@"), !host.contains("\n") else { throw RadioError.message("代理地址或端口无效") }
        let scheme = ["HTTP":"http", "HTTPS":"https", "SOCKS4":"socks4", "SOCKS5":"socks5h"][proto] ?? "http"
        return Route(proxy: "\(scheme)://\(host):\(port)", username: user, password: pass, auth: auth)
    }
    func curlArguments(_ url: URL) -> [String] {
        var a = ["--silent", "--show-error", "--fail", "--location", "--max-redirs", "8", "--connect-timeout", "15", "--proto", "=http,https", "--proto-redir", "=http,https", "--user-agent", "DeutsiaRadioMac/1.0"]
        if let proxy { a += ["--proxy", proxy, "--noproxy", ""] } else { a += ["--proxy", ""] }
        // Credentials use a private stdin config, never process arguments.
        a += ["--config", "-", url.absoluteString]
        return a
    }
    func configure(_ p: Process) {
        let input = Pipe(); p.standardInput = input
        let escape: (String) -> String = { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "") }
        var config = ""
        if !username.isEmpty {
            config = "proxy-user = \"\(escape(username)):\(escape(password))\"\n"
            config += auth == "DIGEST" ? "proxy-digest\n" : "proxy-basic\n"
        }
        input.fileHandleForWriting.write(Data(config.utf8)); try? input.fileHandleForWriting.close()
    }
    func fetch(_ url: URL) throws -> Data {
        _ = try validateStream(url.absoluteString)
        let p = Process(), out = Pipe(), err = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        p.arguments = curlArguments(url) + ["--max-time", "35", "--max-filesize", "16777216"]
        p.standardOutput = out; p.standardError = err; configure(p)
        let token = try NetworkPolicy.shared.begin(expected: generation, start: { try p.run() }, cancel: { if p.isRunning { p.terminate() } })
        defer { NetworkPolicy.shared.finish(token) }
        let bytes = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw RadioError.message(String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "网络请求失败") }
        return bytes
    }
}
final class StreamRelay {
    private var listener: NWListener?
    private let lock = NSLock()
    private var routes: [String:(URL, Route)] = [:]
    private var processes: [UUID:Process] = [:]
    private var connections: [UUID:NWConnection] = [:]
    private(set) var port: UInt16 = 0
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let l = try NWListener(using: parameters)
        let sem = DispatchSemaphore(value: 0)
        l.stateUpdateHandler = { state in if case .ready = state { self.port = l.port!.rawValue; sem.signal() }; if case .failed = state { sem.signal() } }
        l.newConnectionHandler = { self.accept($0) }
        l.start(queue: DispatchQueue(label: "radio.relay"))
        guard sem.wait(timeout: .now() + 5) == .success, port != 0 else { l.cancel(); throw RadioError.message("无法启动本机播放通道") }
        listener = l
    }
    func local(_ remote: URL, route: Route) -> URL {
        let id = UUID().uuidString
        lock.lock(); routes[id] = (remote, route); lock.unlock()
        let ext = remote.pathExtension.isEmpty ? "stream" : remote.pathExtension
        return URL(string: "http://127.0.0.1:\(port)/\(id).\(ext)")!
    }
    func mapped(_ remote: URL, route: Route) -> String {
        var origin = URLComponents(url:remote,resolvingAgainstBaseURL:true)!
        let path = origin.percentEncodedPath; let query = origin.percentEncodedQuery
        origin.path = "/"; origin.query = nil; origin.fragment = nil
        let key = UUID().uuidString
        lock.lock(); routes[key] = (origin.url!,route); lock.unlock()
        return "http://127.0.0.1:\(port)/\(key)/" + (path.hasPrefix("/") ? String(path.dropFirst()) : path) + (query.map { "?"+$0 } ?? "")
    }
    func reset() {
        lock.lock(); let ps = Array(processes.values), cs = Array(connections.values); processes.removeAll(); connections.removeAll(); routes.removeAll(); lock.unlock()
        for p in ps where p.isRunning { p.terminate() }; for c in cs { c.cancel() }
    }
    private func accept(_ c: NWConnection) {
        let id = UUID(); lock.lock(); connections[id] = c; lock.unlock()
        c.start(queue: DispatchQueue.global())
        receive(c, id: id, buffer: Data())
    }
    private func receive(_ c: NWConnection, id: UUID, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, done, error in
            var b = buffer; if let data { b.append(data) }
            guard b.count < 32768 else { c.cancel(); return }
            if let text = String(data: b, encoding: .utf8), text.contains("\r\n\r\n") {
                let parts = text.components(separatedBy: "\r\n")[0].split(separator: " ")
                guard parts.count > 1, parts[0] == "GET" || parts[0] == "HEAD" else { c.cancel(); return }
                let rawPath = String(parts[1].dropFirst())
                let first = rawPath.split(separator:"/",maxSplits:1).first.map(String.init) ?? ""
                let key = String(first.split(separator:".")[0])
                self.lock.lock(); let target = self.routes[key]; self.lock.unlock()
                guard let (storedURL, route) = target else { c.cancel(); return }
                let url: URL
                if let slash = rawPath.firstIndex(of:"/") { guard let mappedURL = URL(string:String(rawPath[rawPath.index(after:slash)...]),relativeTo:storedURL)?.absoluteURL else { c.cancel(); return }; url = mappedURL } else { url = storedURL }
                DispatchQueue.global().async { self.serve(c, id: id, url: url, route: route, head: parts[0] == "HEAD") }
            } else if !done && error == nil { self.receive(c, id: id, buffer: b) } else { c.cancel() }
        }
    }
    private func send(_ c: NWConnection, _ bytes: Data) -> Bool {
        let sem = DispatchSemaphore(value: 0); var ok = true
        c.send(content: bytes, completion: .contentProcessed { e in ok = e == nil; sem.signal() })
        return sem.wait(timeout: .now() + 20) == .success && ok
    }
    private func serve(_ c: NWConnection, id: UUID, url: URL, route: Route, head: Bool) {
        let p = Process(), out = Pipe()
        let header = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if p.isRunning { p.terminate() }; c.cancel(); try? FileManager.default.removeItem(at: header); lock.lock(); processes.removeValue(forKey: id); connections.removeValue(forKey: id); lock.unlock() }
        guard (try? validateStream(url.absoluteString)) != nil else { return }
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl"); p.arguments = route.curlArguments(url) + ["--header", "Icy-MetaData: 1", "--dump-header", header.path]
        p.standardOutput = out; p.standardError = FileHandle.nullDevice; route.configure(p)
        lock.lock(); processes[id] = p; lock.unlock()
        do { try p.run() } catch { return }
        var first = out.fileHandleForReading.readData(ofLength: 4096)
        guard !first.isEmpty else { return }
        let prefix = String(data: first, encoding: .utf8) ?? ""
        if prefix.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") || prefix.lowercased().hasPrefix("[playlist]") || ["m3u", "m3u8", "pls", "mpd"].contains(url.pathExtension.lowercased()) || prefix.contains("<MPD") {
            while first.count < 4_194_304 {
                let chunk = out.fileHandleForReading.readData(ofLength: 16384); if chunk.isEmpty { break }; first.append(chunk)
            }
            guard first.count < 4_194_304, let playlist = String(data: first, encoding: .utf8) else { return }
            var base = url
            if let h = try? String(contentsOf: header, encoding: .utf8) {
                for line in h.components(separatedBy: .newlines) where line.lowercased().hasPrefix("location:") {
                    if let u = URL(string: String(line.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: base)?.absoluteURL { base = u }
                }
            }
            let isDASH = playlist.contains("<MPD") || url.pathExtension.lowercased() == "mpd"
            let rewritten: String
            if isDASH { guard let manifest = try? rewriteDASH(playlist,base:base,transform:{ self.mapped($0,route:route) }) else { return }; rewritten = manifest }
            else { rewritten = rewritePlaylist(playlist, base: base) { self.local($0, route: route).absoluteString } }
            let contentType = isDASH ? "application/dash+xml" : "application/vnd.apple.mpegurl"
            let body = Data(rewritten.utf8)
            guard send(c, Data("HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)) else { return }
            if !head { _ = send(c, body) }
        } else {
            let allowed = ["content-type", "icy-metaint", "icy-name", "icy-genre", "icy-url", "icy-br"]
            let rawHeaders = (try? String(contentsOf:header,encoding:.utf8)) ?? ""
            let finalHeader = rawHeaders.components(separatedBy:"\r\n\r\n").last(where:{ !$0.isEmpty }) ?? ""
            let forwarded = finalHeader.components(separatedBy:"\r\n").filter { line in allowed.contains(line.split(separator:":",maxSplits:1).first.map { $0.lowercased() } ?? "") }.joined(separator:"\r\n")
            let headers = "HTTP/1.1 200 OK\r\n" + (forwarded.isEmpty ? "Content-Type: application/octet-stream" : forwarded) + "\r\nConnection: close\r\n\r\n"
            guard send(c, Data(headers.utf8)), !head else { return }
            guard send(c, first) else { return }
            while p.isRunning {
                let chunk = out.fileHandleForReading.readData(ofLength: 16384)
                if chunk.isEmpty || !send(c, chunk) { break }
            }
        }
    }
}
