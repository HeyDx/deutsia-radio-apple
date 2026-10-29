import Foundation
func rewritePlaylist(_ text: String, base: URL, transform: (URL) -> String) -> String {
    let lines = text.components(separatedBy: .newlines)
    if text.lowercased().hasPrefix("[playlist]") {
        return "#EXTM3U\n" + lines.filter { $0.lowercased().hasPrefix("file") }.compactMap { line in
            let value = line.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
            guard let u = URL(string: value, relativeTo: base)?.absoluteURL, (try? validateStream(u.absoluteString)) != nil else { return nil }
            return transform(u)
        }.joined(separator: "\n")
    }
    return lines.map { line -> String in
        let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return line }
        if clean.hasPrefix("#") {
            let regex = try! NSRegularExpression(pattern: "URI=\"([^\"]+)\"")
            var result = line
            for m in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).reversed() {
                if let r = Range(m.range(at: 1), in: result) {
                    if let u = URL(string: String(result[r]), relativeTo: base)?.absoluteURL, (try? validateStream(u.absoluteString)) != nil { result.replaceSubrange(r, with: transform(u)) }
                    else { result.replaceSubrange(r, with: "http://127.0.0.1:1/blocked") }
                }
            }
            return result
        }
        guard let u = URL(string: clean, relativeTo: base)?.absoluteURL, (try? validateStream(u.absoluteString)) != nil else { return "" }
        return transform(u)
    }.joined(separator: "\n")
}
