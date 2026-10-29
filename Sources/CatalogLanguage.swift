import Foundation
func stationLanguageTerms(_ selected: String) -> [String] {
    switch selected {
    case "@chinese": return ["chinese","mandarin","cantonese","中文","粤语"]
    case "@mandarin": return ["chinese","mandarin","chinese simplified","simplified chinese","普通话"]
    case "@cantonese": return ["cantonese","粤语","yue"]
    default: return selected.isEmpty ? [""] : [selected]
    }
}
func stationSearchURLs(base: URL, language: String, i2p: Bool) -> [URL] {
    guard !i2p else { return [base] }
    return stationLanguageTerms(language).compactMap { term in
        var c = URLComponents(url:base,resolvingAgainstBaseURL:true)!
        c.queryItems = (c.queryItems ?? []).filter { $0.name != "language" }
        if !term.isEmpty { c.queryItems!.append(URLQueryItem(name:"language",value:term)) }
        return c.url
    }
}
