import Foundation
private func xmlEscape(_ s: String) -> String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;") }
private final class DashRewriter: NSObject, XMLParserDelegate {
    struct Frame { var name: String; var base: URL; var text = "" }
    var frames: [Frame] = []
    var output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    let base: URL
    let transform: (URL)->String
    var failure: Error?
    init(base: URL, transform: @escaping (URL)->String) { self.base = base; self.transform = transform }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String:String]) {
        let current = frames.last?.base ?? base
        frames.append(Frame(name:elementName,base:current))
        var attrs = attributeDict
        for (key,value) in attributeDict {
            let uriKeys = ["media","initialization","sourceURL","xlink:href"]
            if uriKeys.contains(key) || ((key == "value" || key == "href") && (value.hasPrefix("http://") || value.hasPrefix("https://"))) {
                guard let u = URL(string:value,relativeTo:current)?.absoluteURL, (try? validateStream(u.absoluteString)) != nil else { failure = RadioError.message("DASH 清单包含不支持的网络地址"); parser.abortParsing(); return }
                attrs[key] = transform(u)
            }
        }
        output += "<"+elementName+attrs.keys.sorted().map { " \($0)=\"\(xmlEscape(attrs[$0]!))\"" }.joined()+">"
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if frames.last?.name == "BaseURL" || frames.last?.name == "Location" { frames[frames.count-1].text += string } else { output += xmlEscape(string) }
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { self.parser(parser,foundCharacters:String(decoding:CDATABlock,as:UTF8.self)) }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let frame = frames.popLast() else { return }
        if elementName == "BaseURL" || elementName == "Location" {
            let value = frame.text.trimmingCharacters(in:.whitespacesAndNewlines)
            guard let u = URL(string:value,relativeTo:frame.base)?.absoluteURL, (try? validateStream(u.absoluteString)) != nil else { failure = RadioError.message("DASH 网络地址无效"); parser.abortParsing(); return }
            output += xmlEscape(transform(u))
            if elementName == "BaseURL", !frames.isEmpty { frames[frames.count-1].base = u }
        }
        output += "</"+elementName+">"
    }
}
func rewriteDASH(_ text: String, base: URL, transform: @escaping (URL)->String) throws -> String {
    let delegate = DashRewriter(base:base,transform:transform)
    let parser = XMLParser(data:Data(text.utf8)); parser.shouldResolveExternalEntities = false; parser.delegate = delegate
    guard parser.parse(), delegate.failure == nil else { throw delegate.failure ?? parser.parserError ?? RadioError.message("DASH 清单解析失败") }
    return delegate.output
}
