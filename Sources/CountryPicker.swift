import SwiftUI
struct CountryPicker: View {
    @EnvironmentObject var s: RadioStore
    var body: some View {
        HStack(spacing:6) {
            Picker("国家",selection:$s.country) {
                Text("全部国家").tag("")
                ForEach(s.countries,id:\.self) { country in Text(displayName(country)).tag(country) }
            }
            .onChange(of:s.country) { _ in s.search() }
            if s.loadingCountries { ProgressView().controlSize(.small) }
            if s.countries.isEmpty && !s.loadingCountries { Button { s.loadCountries() } label: { Image(systemName:"arrow.clockwise") }.buttonStyle(.plain).help("重新加载国家选单") }
        }.task { s.loadCountries() }
    }
    func displayName(_ english: String) -> String {
        let current = Locale(identifier:s.library.preferences.language == "zh" ? "zh-Hans" : s.library.preferences.language)
        let aliases = ["China":"CN", "The United States Of America":"US", "The United Kingdom Of Great Britain And Northern Ireland":"GB", "Taiwan, Republic Of China":"TW", "The Republic Of Korea":"KR", "The Russian Federation":"RU", "The Netherlands":"NL", "Myanmar":"MM", "Islamic Republic Of Iran":"IR", "The Philippines":"PH", "The United Arab Emirates":"AE", "Bolivarian Republic Of Venezuela":"VE", "Bosnia And Herzegovina":"BA", "Antigua And Barbuda":"AG", "Republic Of North Macedonia":"MK", "State Of Palestine":"PS", "Brunei Darussalam":"BN", "The Bahamas":"BS", "The Democratic Peoples Republic Of Korea":"KP"]
        if english == "China", current.identifier.hasPrefix("zh") { return "中国" }
        if let code = aliases[english], let name = current.localizedString(forRegionCode:code) { return name }
        let englishLocale = Locale(identifier:"en_US")
        if let code = Locale.Region.isoRegions.first(where:{ englishLocale.localizedString(forRegionCode:$0.identifier) == english })?.identifier,
           let localized = current.localizedString(forRegionCode:code) { return localized }
        return english
    }
}
