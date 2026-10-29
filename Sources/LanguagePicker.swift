import SwiftUI
struct LanguagePicker: View {
    @EnvironmentObject var s: RadioStore
    let languages = [("zh","中文"),("en","English"),("ar","العربية"),("de","Deutsch"),("es","Español"),("fa","فارسی"),("fr","Français"),("hi","हिन्दी"),("it","Italiano"),("ja","日本語"),("ko","한국어"),("my","မြန်မာ"),("pt","Português"),("ru","Русский"),("tr","Türkçe"),("uk","Українська"),("vi","Tiếng Việt")]
    var body: some View { Picker("语言",selection:$s.library.preferences.language) { ForEach(languages,id:\.0) { code,name in Text(name).tag(code) } }.onChange(of:s.library.preferences.language) { _ in s.save() } }
}
