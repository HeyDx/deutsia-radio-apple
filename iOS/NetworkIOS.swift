import Foundation
import Network
struct Route {
    var generation = NetworkPolicy.shared.generation
    var proxy: String? = nil
    var username = ""
    var password = ""
    var auth = "NONE"
    static func make(station: Station?, prefs: Preferences) throws -> Route {
        if let s = station, s.network == "I2P" || s.proxyType == "I2P" { return try configured("HTTP",prefs.i2pHost,prefs.i2pPort,"","","NONE") }
        if let s = station, s.proxyType == "CUSTOM" { return try configured(s.customProxyProtocol,s.proxyHost,s.proxyPort,s.proxyUsername,s.proxyPassword,s.proxyAuthType) }
        if prefs.forceProxy { return try configured(prefs.proxyProtocol,prefs.proxyHost,prefs.proxyPort,prefs.proxyUsername,prefs.proxyPassword,prefs.proxyAuthType) }
        return Route()
    }
    static func configured(_ proto: String, _ host: String, _ port: Int, _ user: String, _ pass: String, _ auth: String) throws -> Route {
        guard !host.isEmpty, (1...65535).contains(port), !host.contains("/"), !host.contains("@") else { throw RadioError.message("代理地址无效") }
        guard proto != "SOCKS4" else { throw RadioError.message("iOS 代理通道暂不支持 SOCKS4，请选择 SOCKS5") }
        return Route(proxy:"\(proto.lowercased())://\(host):\(port)",username:user,password:pass,auth:auth)
    }
    func session() throws -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.urlCache = nil; c.httpCookieStorage = nil; c.timeoutIntervalForRequest = 30
        c.httpAdditionalHeaders = ["User-Agent":"DeutsiaRadioiOS/0.1"]
        if let proxy, let u = URL(string:proxy), let host = u.host, let port = u.port, let endpointPort = NWEndpoint.Port(rawValue:UInt16(port)) {
            let endpoint = NWEndpoint.hostPort(host:NWEndpoint.Host(host),port:endpointPort)
            var p = u.scheme == "socks5" ? ProxyConfiguration(socksv5Proxy:endpoint) : ProxyConfiguration(httpCONNECTProxy:endpoint,tlsOptions:u.scheme == "https" ? NWProtocolTLS.Options() : nil)
            p.allowFailover = false
            if !username.isEmpty { p.applyCredential(username:username,password:password) }
            c.proxyConfigurations = [p]
        }
        return URLSession(configuration:c,delegate:RedirectGuard(),delegateQueue:nil)
    }
    func fetch(_ url: URL) async throws -> Data {
        _ = try validateStream(url.absoluteString)
        let s = try session()
        let token = try NetworkPolicy.shared.begin(expected:generation,start:{},cancel:{ s.invalidateAndCancel() })
        defer { s.finishTasksAndInvalidate(); NetworkPolicy.shared.finish(token) }
        let (bytes,response) = try await s.data(from:url)
        guard let r = response as? HTTPURLResponse, (200..<300).contains(r.statusCode), bytes.count < 16_777_216 else { throw RadioError.message("目录请求失败") }
        return bytes
    }
}
final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { (try? validateStream($0.absoluteString)) != nil ? request : nil })
    }
}
final class StreamRelay {
    private var listener: NWListener?
    private let lock = NSLock()
    private var routes: [String:(URL,Route)] = [:]
    private var tasks: [UUID:Task<Void,Never>] = [:]
    private var connections: [UUID:NWConnection] = [:]
    private(set) var port: UInt16 = 0
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        let l = try NWListener(using:parameters), sem = DispatchSemaphore(value:0)
        l.stateUpdateHandler = { state in if case .ready = state { self.port = l.port!.rawValue; sem.signal() }; if case .failed = state { sem.signal() } }
        l.newConnectionHandler = { c in self.accept(c) }; l.start(queue:DispatchQueue(label:"radio.ios.relay"))
        guard sem.wait(timeout:.now()+5) == .success, port != 0 else { l.cancel(); throw RadioError.message("本机播放通道启动失败") }; listener = l
    }
    func local(_ url: URL, route: Route) -> URL {
        let id = UUID().uuidString
        lock.lock(); routes[id] = (url,route); lock.unlock()
        return URL(string:"http://127.0.0.1:\(port)/\(id).\(url.pathExtension.isEmpty ? "stream" : url.pathExtension)")!
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
        lock.lock(); let ts = Array(tasks.values), cs = Array(connections.values); tasks.removeAll(); connections.removeAll(); routes.removeAll(); lock.unlock()
        ts.forEach { $0.cancel() }; cs.forEach { $0.cancel() }
    }
    private func accept(_ c: NWConnection) {
        let id = UUID(); lock.lock(); connections[id] = c; lock.unlock()
        c.start(queue:DispatchQueue.global()); receive(c,id:id,buffer:Data())
    }
    private func receive(_ c: NWConnection,id: UUID,buffer: Data) {
        c.receive(minimumIncompleteLength:1,maximumLength:8192) { data,_,done,error in
            var b = buffer; if let data { b.append(data) }; guard b.count < 32768 else { c.cancel(); return }
            if let text = String(data:b,encoding:.utf8), text.contains("\r\n\r\n") {
                let parts = text.components(separatedBy:"\r\n")[0].split(separator:" ")
                guard parts.count > 1, parts[0] == "GET" else { c.cancel(); return }
                let rawPath = String(parts[1].dropFirst()), first = rawPath.split(separator:"/",maxSplits:1).first.map(String.init) ?? ""
                let key = String(first.split(separator:".")[0])
                self.lock.lock(); let target = self.routes[key]; self.lock.unlock()
                guard let target else { c.cancel(); return }
                var url = target.0
                if let slash = rawPath.firstIndex(of:"/"), let mapped = URL(string:String(rawPath[rawPath.index(after:slash)...]),relativeTo:target.0)?.absoluteURL { url = mapped }
                let t = Task { await self.serve(c,id:id,url:url,route:target.1) }
                self.lock.lock(); self.tasks[id] = t; self.lock.unlock()
            } else if !done && error == nil { self.receive(c,id:id,buffer:b) } else { c.cancel() }
        }
    }
    private func send(_ c: NWConnection,_ bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
            c.send(content:bytes,completion:.contentProcessed { e in if let e { continuation.resume(throwing:e) } else { continuation.resume() } })
        }
    }
    private func cleanup(_ id: UUID) { lock.lock(); tasks.removeValue(forKey:id); connections.removeValue(forKey:id); lock.unlock() }
    private func serve(_ c: NWConnection,id: UUID,url: URL,route: Route) async {
        defer { c.cancel(); cleanup(id) }
        do {
            _ = try validateStream(url.absoluteString)
            let session = try route.session(); defer { session.invalidateAndCancel() }
            let (bytes,response) = try await session.bytes(from:url)
            guard let r = response as? HTTPURLResponse, (200..<300).contains(r.statusCode) else { return }
            let playlist = ["m3u8","m3u","pls","mpd"].contains(url.pathExtension.lowercased()) || (r.mimeType?.contains("mpegurl") ?? false) || (r.mimeType?.contains("scpls") ?? false) || (r.mimeType?.contains("dash+xml") ?? false)
            var data = Data()
            if playlist {
                for try await byte in bytes { try Task.checkCancellation(); data.append(byte); if data.count > 4_194_304 { return } }
                let text = String(decoding:data,as:UTF8.self)
                let isDASH = text.contains("<MPD") || url.pathExtension == "mpd"
                let rewritten = isDASH ? try rewriteDASH(text,base:r.url ?? url) { self.mapped($0,route:route) } : rewritePlaylist(text,base:r.url ?? url) { self.local($0,route:route).absoluteString }
                let body = Data(rewritten.utf8), mime = isDASH ? "application/dash+xml" : "application/vnd.apple.mpegurl"
                try await send(c,Data("HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)); try await send(c,body)
            } else {
                try await send(c,Data("HTTP/1.1 200 OK\r\nContent-Type: \(r.mimeType ?? "application/octet-stream")\r\nConnection: close\r\n\r\n".utf8))
                for try await byte in bytes {
                    try Task.checkCancellation(); data.append(byte)
                    if data.count >= 8192 { try await send(c,data); data.removeAll(keepingCapacity:true) }
                }
                if !data.isEmpty { try await send(c,data) }
            }
        } catch { }
    }
}
