import SwiftUI
struct GenreManager: View {
    @EnvironmentObject var s: RadioStore
    @Environment(\.dismiss) var dismiss
    @State var selected = ""
    @State var newName = ""
    var genres: [String] { Array(Set(s.library.stations.map(\.genre))).sorted() }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("管理类型").font(.title2.bold())
            Text("重命名会更新所有相关电台；删除类型后，电台会归入 Other。").font(.caption).foregroundStyle(.secondary)
            Picker("类型",selection:$selected) { Text("选择类型").tag(""); ForEach(genres,id:\.self) { Text($0).tag($0) } }
            TextField("新类型名称",text:$newName).textFieldStyle(.roundedBorder)
            HStack {
                Button("重命名") { s.renameGenre(selected,to:newName); selected = newName; newName = "" }.disabled(selected.isEmpty || newName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                Button("删除类型",role:.destructive) { s.renameGenre(selected,to:"Other"); selected = "" }.disabled(selected.isEmpty || selected == "Other")
                Spacer(); Button("完成") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(idealWidth:450)
    }
}
