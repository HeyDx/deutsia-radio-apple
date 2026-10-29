// macOS adaptation of deutsia radio (Apache-2.0), 2026-10-29.
import Foundation
import CryptoKit
import Security

struct Station: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var name = ""
    var streamUrl = ""
    var genre = "Other"
    var country = ""
    var codec = ""
    var bitrate = 0
    var isLiked = false
    var proxyType = "NONE"
    var proxyHost = "127.0.0.1"
    var proxyPort = 4444
    var customProxyProtocol = "HTTP"
    var proxyUsername = ""
    var proxyPassword = ""
    var proxyAuthType = "NONE"
    var coverArtUri = ""
    var lastPlayedAt: Double = 0
    var network: String { URL(string: streamUrl)?.host?.lowercased().hasSuffix(".i2p") == true ? "I2P" : "Internet" }
    static func from(_ d: [String: Any]) -> Station {
        var s = Station()
        s.id = d["id"] as? String ?? d["stationuuid"] as? String ?? s.id
        s.name = d["name"] as? String ?? "Radio"
        s.streamUrl = d["streamUrl"] as? String ?? d["url_resolved"] as? String ?? d["url"] as? String ?? ""
        s.genre = d["genre"] as? String ?? d["tags"] as? String ?? "Other"
        s.country = d["country"] as? String ?? ""
        s.codec = d["codec"] as? String ?? ""
        s.bitrate = d["bitrate"] as? Int ?? 0
        s.isLiked = d["isLiked"] as? Bool ?? false
        s.proxyType = d["proxyType"] as? String ?? (s.network == "I2P" ? "I2P" : "NONE")
        s.proxyHost = d["proxyHost"] as? String ?? "127.0.0.1"
        s.proxyPort = d["proxyPort"] as? Int ?? 4444
        s.coverArtUri = d["coverArtUri"] as? String ?? d["favicon"] as? String ?? d["faviconUrl"] as? String ?? ""
        return s
    }
}
struct Preferences: Codable {
    var i2pHost = "127.0.0.1"
    var i2pPort = 4444
    var forceProxy = false
    var proxyHost = "127.0.0.1"
    var proxyPort = 8080
    var proxyProtocol = "HTTP"
    var proxyUsername = ""
    var proxyPassword = ""
    var proxyAuthType = "NONE"
    var radioBrowser = true
    var registry = true
    var artwork = true
    var encrypted = false
    var pinHash = ""
    var pinSalt = ""
    var theme = "system"
    var accent = "purple"
    var language = "zh"
    var recordAcrossStations = false
    var volume: Double = 80

    init() {}
    enum CodingKeys: String, CodingKey { case i2pHost,i2pPort,forceProxy,proxyHost,proxyPort,proxyProtocol,proxyUsername,proxyPassword,proxyAuthType,radioBrowser,registry,artwork,encrypted,pinHash,pinSalt,theme,accent,language,recordAcrossStations,volume }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        i2pHost = try c.decodeIfPresent(String.self, forKey: .i2pHost) ?? i2pHost
        i2pPort = try c.decodeIfPresent(Int.self, forKey: .i2pPort) ?? i2pPort
        forceProxy = try c.decodeIfPresent(Bool.self, forKey: .forceProxy) ?? forceProxy
        proxyHost = try c.decodeIfPresent(String.self, forKey: .proxyHost) ?? proxyHost
        proxyPort = try c.decodeIfPresent(Int.self, forKey: .proxyPort) ?? proxyPort
        proxyProtocol = try c.decodeIfPresent(String.self, forKey: .proxyProtocol) ?? proxyProtocol
        proxyUsername = try c.decodeIfPresent(String.self, forKey: .proxyUsername) ?? proxyUsername
        proxyPassword = try c.decodeIfPresent(String.self, forKey: .proxyPassword) ?? proxyPassword
        proxyAuthType = try c.decodeIfPresent(String.self, forKey: .proxyAuthType) ?? proxyAuthType
        radioBrowser = try c.decodeIfPresent(Bool.self, forKey: .radioBrowser) ?? radioBrowser
        registry = try c.decodeIfPresent(Bool.self, forKey: .registry) ?? registry
        artwork = try c.decodeIfPresent(Bool.self, forKey: .artwork) ?? artwork
        encrypted = try c.decodeIfPresent(Bool.self, forKey: .encrypted) ?? encrypted
        pinHash = try c.decodeIfPresent(String.self, forKey: .pinHash) ?? pinHash
        pinSalt = try c.decodeIfPresent(String.self, forKey: .pinSalt) ?? pinSalt
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? theme
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? accent
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? language
        recordAcrossStations = try c.decodeIfPresent(Bool.self, forKey: .recordAcrossStations) ?? recordAcrossStations
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? volume
    }
}
struct Library: Codable {
    var stations: [Station] = []
    var history: [Station] = []
    var queue: [Station] = []
    var preferences = Preferences()
}
enum RadioError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}
func validateStream(_ value: String) throws -> URL {
    guard let u = URL(string: value), let host = u.host?.lowercased(), ["http", "https"].contains(u.scheme?.lowercased() ?? ""), !host.isEmpty else { throw RadioError.message("请输入有效的 HTTP / HTTPS 电台地址") }
    guard !host.hasSuffix(".onion") else { throw RadioError.message("此 macOS 版本不支持 Tor / .onion 电台") }
    return u
}
final class Vault {
    let folder: URL
    private var cachedKey: SymmetricKey?
    private let keyProvider: (() throws -> SymmetricKey)?
    init(folder: URL? = nil, key explicitKey: SymmetricKey? = nil, keyProvider: (() throws -> SymmetricKey)? = nil) throws {
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DeutsiaRadioMac")
        try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        cachedKey = explicitKey
        self.keyProvider = keyProvider
        // No Keychain access until encrypted data must actually be read or saved.
    }
    private func encryptionKey() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        if let keyProvider { let key = try keyProvider(); cachedKey = key; return key }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.deutsia.mac.vault", kSecAttrAccount as String: "local-encryption-key"]
        var result: CFTypeRef?
        var read = query; read[kSecReturnData as String] = true; read[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        let key: SymmetricKey
        if status == errSecSuccess, let data = result as? Data { key = SymmetricKey(data:data) }
        else if status == errSecItemNotFound {
            let newKey = SymmetricKey(size:.bits256)
            var add = query; add[kSecValueData as String] = newKey.withUnsafeBytes { Data($0) }; add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(add as CFDictionary,nil) == errSecSuccess else { throw RadioError.message("无法保存应用资料库的加密密钥；未读取其他钥匙串条目") }
            key = newKey
        } else { throw RadioError.message("应用资料库加密密钥读取未获授权或失败：\(status)") }
        cachedKey = key
        return key
    }
    func load() throws -> Library {
        let u = folder.appendingPathComponent("library.dat")
        guard FileManager.default.fileExists(atPath: u.path) else { return Library() }
        let raw = try Data(contentsOf: u)
        let bytes = raw.starts(with: Data("DRM1".utf8)) ? try AES.GCM.open(AES.GCM.SealedBox(combined: raw.dropFirst(4)), using: encryptionKey()) : raw
        return try JSONDecoder().decode(Library.self, from: bytes)
    }
    func save(_ library: Library) throws {
        var bytes = try JSONEncoder().encode(library)
        // Encrypt the entire library whenever requested; credentials are always protected.
        if library.preferences.encrypted || !library.preferences.proxyPassword.isEmpty || library.stations.contains(where: { !$0.proxyPassword.isEmpty }) {
            bytes = Data("DRM1".utf8) + (try AES.GCM.seal(bytes, using: encryptionKey()).combined!)
        }
        let u = folder.appendingPathComponent("library.dat")
        try bytes.write(to: u, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: u.path)
    }
}
func pinDigest(_ pin: String, salt: String) -> String {
    // PBKDF2-HMAC-SHA256, implemented with CommonCrypto in Security.swift.
    derivePIN(pin, salt: salt)
}
