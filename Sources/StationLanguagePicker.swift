import SwiftUI
struct StationLanguagePicker: View {
    @EnvironmentObject var s: RadioStore
    var body: some View {
        HStack(spacing:6) {
            Picker("电台语言",selection:$s.stationLanguage) {
                Text("全部语言").tag("")
                Section("汉语") {
                    Text("全部汉语（含普通话、粤语）").tag("@chinese")
                    Text("普通话／简体中文").tag("@mandarin")
                    Text("粤语").tag("@cantonese")
                }
                Section("其他语言") {
                    ForEach(s.stationLanguages.filter { !["chinese","mandarin","cantonese"].contains($0.lowercased()) },id:\.self) { language in Text(displayName(language)).tag(language) }
                }
            }.onChange(of:s.stationLanguage) { _ in s.search() }
            if s.loadingLanguages { ProgressView().controlSize(.small) }
            if s.stationLanguages.isEmpty && !s.loadingLanguages { Button { s.loadStationLanguages() } label: { Image(systemName:"arrow.clockwise") }.buttonStyle(.plain).help("重新加载语言选单") }
        }.task { s.loadStationLanguages() }
    }
    func displayName(_ language: String) -> String {
        let codes = ["english":"en","german":"de","spanish":"es","french":"fr","russian":"ru","portuguese":"pt","italian":"it","japanese":"ja","korean":"ko","arabic":"ar","hindi":"hi","turkish":"tr","ukrainian":"uk","vietnamese":"vi","dutch":"nl","polish":"pl","greek":"el","thai":"th","indonesian":"id","malay":"ms","persian":"fa","swedish":"sv","danish":"da","norwegian":"no","finnish":"fi","romanian":"ro","czech":"cs"]
        if let code = codes[language.lowercased()] {
            return Locale(identifier:s.library.preferences.language == "zh" ? "zh-Hans" : s.library.preferences.language).localizedString(forLanguageCode:code) ?? language.capitalized
        }
        return language.capitalized
    }
}
