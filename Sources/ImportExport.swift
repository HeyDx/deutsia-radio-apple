import Foundation
func csvRows(_ text: String) -> [[String]] {
    var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
    let chars = Array(text); var i = 0
    while i < chars.count {
        let c = chars[i]
        if c == "\"" {
            if quoted && i + 1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 } else { quoted.toggle() }
        } else if c == "," && !quoted { row.append(field); field = "" }
        else if c == "\n" && !quoted { row.append(field.trimmingCharacters(in: .newlines)); rows.append(row); row = []; field = "" }
        else { field.append(c) }
        i += 1
    }
    if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
    return rows
}
func importStations(_ data: Data, ext: String) throws -> [Station] {
    var found: [Station] = []
    guard let text = String(data: data, encoding: .utf8) else { throw RadioError.message("文件须使用 UTF-8 编码") }
    if ext == "json" || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
        let root = try JSONSerialization.jsonObject(with: data)
        let items = root as? [[String:Any]] ?? (root as? [String:Any])?["stations"] as? [[String:Any]] ?? []
        found = items.map(Station.from)
    } else if ext == "csv" {
        let rows = csvRows(text)
        guard let first = rows.first else { return [] }
        let keys = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        found = rows.dropFirst().map { values in
            var d: [String:Any] = [:]
            for (i, key) in keys.enumerated() where i < values.count { d[key] = values[i] }
            d["isLiked"] = (d["isLiked"] as? String)?.lowercased() == "true"
            d["proxyPort"] = Int(d["proxyPort"] as? String ?? "") ?? 4444
            return Station.from(d)
        }
    } else if ext == "pls" || text.lowercased().hasPrefix("[playlist]") {
        var urls: [String:String] = [:], titles: [String:String] = [:]
        for l in text.components(separatedBy: .newlines) {
            let p = l.split(separator: "=", maxSplits: 1).map(String.init); guard p.count == 2 else { continue }
            if p[0].lowercased().hasPrefix("file") { urls[String(p[0].dropFirst(4))] = p[1] }
            if p[0].lowercased().hasPrefix("title") { titles[String(p[0].dropFirst(5))] = p[1] }
        }
        found = urls.keys.sorted().map { Station.from(["name":titles[$0] ?? "Radio \($0)", "url":urls[$0]!]) }
    } else {
        var name = "Radio"
        for line in text.components(separatedBy: .newlines) {
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if l.hasPrefix("#EXTINF:"), let comma = l.firstIndex(of: ",") { name = String(l[l.index(after: comma)...]) }
            else if !l.isEmpty && !l.hasPrefix("#") { found.append(Station.from(["name":name, "url":l])); name = "Radio" }
        }
    }
    let valid = found.filter { !$0.name.isEmpty && (try? validateStream($0.streamUrl)) != nil && $0.proxyType != "TOR" }
    guard !valid.isEmpty else { throw RadioError.message("没有可导入的电台（Tor 电台会被跳过）") }
    return valid
}
func exportStations(_ stations: [Station], ext: String) throws -> Data {
    func quote(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    switch ext {
    case "csv":
        let header = "name,url,proxyType,proxyHost,proxyPort,genre,coverArtUri,isLiked\n"
        return Data((header + stations.map { s in [quote(s.name),quote(s.streamUrl),s.proxyType,quote(s.proxyHost),String(s.proxyPort),quote(s.genre),quote(s.coverArtUri),String(s.isLiked)].joined(separator: ",") }.joined(separator: "\n")).utf8)
    case "m3u": return Data(("#EXTM3U\n" + stations.map { "#EXTINF:-1,\($0.name)\n\($0.streamUrl)" }.joined(separator: "\n")).utf8)
    case "pls": return Data(("[playlist]\n" + stations.enumerated().map { "File\($0.offset+1)=\($0.element.streamUrl)\nTitle\($0.offset+1)=\($0.element.name)" }.joined(separator: "\n") + "\nNumberOfEntries=\(stations.count)\nVersion=2").utf8)
    default:
        let items = stations.map { s -> [String:Any] in ["name":s.name,"streamUrl":s.streamUrl,"genre":s.genre,"isLiked":s.isLiked,"proxyType":s.proxyType,"proxyHost":s.proxyHost,"proxyPort":s.proxyPort,"coverArtUri":s.coverArtUri] }
        return try JSONSerialization.data(withJSONObject: ["version":1,"app":"deutsia radio macOS","stations":items], options: [.prettyPrinted,.sortedKeys])
    }
}
