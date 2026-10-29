import SwiftUI
import UniformTypeIdentifiers
@main struct DeutsiaIOSApp: App {
    @StateObject var store = RadioStore()
    var body: some Scene { WindowGroup { MobileHome().environmentObject(store).tint(store.accent).environment(\.locale,Locale(identifier:store.library.preferences.language == "zh" ? "zh-Hans" : store.library.preferences.language)).preferredColorScheme(store.library.preferences.theme == "light" ? .light : store.library.preferences.theme == "system" ? nil : .dark) } }
}
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json,.commaSeparatedText,.plainText,.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
struct MobileHome: View {
    @EnvironmentObject var s: RadioStore
    @State var add = false
    @State var edited: Station?
    @State var importing = false
    @State var exporting = false
    @State var document = ExportDocument(data:Data())
    @State var exportExt = "json"
    @State var fullPlayer = false
    @State var manageGenres = false
    @State var pin = ""
    var body: some View {
        ZStack {
            TabView(selection:$s.section) {
                NavigationStack { discovery }.tabItem { Label("发现",systemImage:"safari") }.tag("discover")
                NavigationStack { mobileLibrary }.tabItem { Label("我的电台",systemImage:"square.stack") }.tag("library")
                NavigationStack { mobileSettings }.tabItem { Label("设置",systemImage:"slider.horizontal.3") }.tag("settings")
            }
            .safeAreaInset(edge:.bottom) { miniPlayer.padding(.horizontal,12).padding(.bottom,50) }
            if s.locked {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                VStack(spacing:22) {
                    Image(systemName:"lock.shield.fill").font(.system(size:50)).foregroundStyle(s.accent)
                    Text("欢迎回来").font(.largeTitle.bold())
                    SecureField("输入 PIN",text:$pin).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                    Button("解锁") { s.unlock(pin); pin = "" }.buttonStyle(.borderedProminent)
                    Button("使用 Face ID / Touch ID") { s.biometricUnlock() }
                }.padding(35).frame(maxWidth:360)
            }
        }
        .onChange(of:s.networkFingerprint) { _,_ in s.settingsChanged() }
        .sheet(isPresented:$add) { MobileEditor(station:Station()) { s.add($0) } }
        .sheet(item:$edited) { station in MobileEditor(station:station) { s.update($0) } }
        .sheet(isPresented:$manageGenres) { GenreManager() }
        .sheet(isPresented:$fullPlayer) { MobilePlayer() }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json,.commaSeparatedText,.plainText,.data]) { result in
            do { let u = try result.get(); let access = u.startAccessingSecurityScopedResource(); defer { if access { u.stopAccessingSecurityScopedResource() } }; s.importData(try Data(contentsOf:u),ext:u.pathExtension.lowercased()) } catch { s.error = error.localizedDescription }
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:exportExt == "json" ? .json : .plainText,defaultFilename:"deutsia-stations.\(exportExt)") { result in if case .failure(let e) = result { s.error = e.localizedDescription } }
        .alert("Deutsia Radio",isPresented:Binding(get:{s.error != nil},set:{if !$0 { s.error = nil }})) { Button("好") { s.error = nil } } message: { Text(s.error ?? "") }
    }
    var discovery: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                VStack(alignment:.leading,spacing:14) {
                    Text("TUNE INTO YOUR WORLD").font(.system(size:10,weight:.bold)).tracking(2).foregroundStyle(.white.opacity(0.6))
                    Text("此刻，听见世界").font(.system(size:30,weight:.bold,design:.rounded)).foregroundStyle(.white)
                    HStack(alignment:.center,spacing:5) { ForEach(0..<30,id:\.self) { i in Capsule().fill(.white.opacity(0.2+Double(i%4)*0.13)).frame(width:4,height:CGFloat([18,36,25,50,38,65,28,47][i%8])) } }.frame(maxWidth:.infinity)
                    Text("音乐、故事与远方，找到你的专属频道。").font(.caption).foregroundStyle(.white.opacity(0.7))
                }.padding(24).frame(maxWidth:.infinity,alignment:.leading).background(LinearGradient(colors:[Color(red:0.27,green:0.12,blue:0.45),.indigo.opacity(0.7)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:25))
                HStack { Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("搜索电台",text:$s.query).submitLabel(.search).onSubmit { s.search() }; Button { s.search() } label: { if s.busy { ProgressView() } else { Image(systemName:"arrow.right.circle.fill").font(.title2) } } }.padding(14).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:15))
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack { ForEach([("热门",""),("爵士","jazz"),("古典","classical"),("电子","electronic"),("新闻","news"),("放松","ambient")],id:\.0) { title,tag in Button(LocalizedStringKey(title)) { s.tag = tag; s.search() }.buttonStyle(.bordered).tint(s.tag == tag ? s.accent : .gray) } }
                }
                CountryPicker()
                StationLanguagePicker()
                HStack { Text("为你发现").font(.title3.bold()); Spacer(); Button("I2P 目录") { s.search(i2p:true) } }
                if s.results.isEmpty { ContentUnavailableView { Label("世界很大，开始探索",systemImage:"antenna.radiowaves.left.and.right") } actions: { Button("浏览热门电台") { s.search() }.buttonStyle(.borderedProminent) } }
                LazyVStack(spacing:12) { ForEach(s.results) { station in stationRow(station) } }
            }.padding(20)
        }.navigationTitle("deutsia radio").toolbar { Button { add = true } label: { Image(systemName:"plus") } }
    }
    @State var libraryTab = "all"
    var libraryItems: [Station] {
        switch libraryTab { case "liked": return s.library.stations.filter(\.isLiked); case "queue": return s.library.queue; case "history": return s.library.history; default: return s.library.stations }
    }
    var mobileLibrary: some View {
        List {
            Picker("资料库",selection:$libraryTab) { Text("全部").tag("all"); Text("收藏").tag("liked"); Text("队列").tag("queue"); Text("历史").tag("history") }.pickerStyle(.segmented).listRowBackground(Color.clear)
            ForEach(Array(libraryItems.enumerated()),id:\.offset) { index,station in
                stationRow(station).listRowSeparator(.hidden).listRowBackground(Color.clear)
                    .swipeActions { Button(role:.destructive) { if libraryTab == "queue" { s.library.queue.remove(at:index); s.save() } else { s.remove(station) } } label: { Label("移除",systemImage:"trash") } }
            }.onMove { source,destination in if libraryTab == "queue" { s.library.queue.move(fromOffsets:source,toOffset:destination); s.save() } else if libraryTab == "all" { s.library.stations.move(fromOffsets:source,toOffset:destination); s.save() } }
            if libraryItems.isEmpty { Text("添加你喜欢的电台，慢慢收藏好声音。").foregroundStyle(.secondary).listRowBackground(Color.clear) }
        }.listStyle(.plain).navigationTitle("我的电台").toolbar { ToolbarItem(placement:.topBarLeading) { EditButton() }; ToolbarItem(placement:.topBarTrailing) { Button { add = true } label: { Image(systemName:"plus") } } }
    }
    func stationRow(_ station: Station) -> some View {
        HStack(spacing:14) {
            StationArtwork(station:station,size:58)
            VStack(alignment:.leading,spacing:6) { Text(station.name).font(.headline).lineLimit(1); Text(station.genre.isEmpty ? station.network : station.genre).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            Spacer(minLength:0)
            Button { s.play(station) } label: { Image(systemName:"play.circle.fill").font(.title).foregroundStyle(s.accent) }.buttonStyle(.plain)
            Menu {
                Button("收藏 / 取消收藏") { s.favorite(station) }; Button("加入我的电台") { s.add(station) }; Button("加入播放队列") { s.enqueue(station) }; Button("编辑") { edited = station }
                Button(s.recordingPlayers[station.id] == nil ? "录制此电台" : "停止此录音") { s.recordStation(station) }
            } label: { Image(systemName:"ellipsis").padding(.vertical,18) }
        }.padding(14).background(Color.primary.opacity(0.04),in:RoundedRectangle(cornerRadius:20))
    }
    var miniPlayer: some View {
        HStack(spacing:12) {
            Image(systemName:"waveform.circle.fill").font(.largeTitle).foregroundStyle(s.accent)
            VStack(alignment:.leading,spacing:4) { Text(s.current?.name ?? "等待一段好声音").font(.subheadline.bold()).lineLimit(1); Text(s.track.isEmpty ? s.status : s.track).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }.onTapGesture { fullPlayer = true }
            Spacer(minLength:0)
            Button { s.toggle() } label: { Image(systemName:s.playing ? "pause.fill" : "play.fill").font(.title3) }
            Button { s.skip(1) } label: { Image(systemName:"forward.end.fill") }
        }.padding(15).background(.regularMaterial,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(s.accent.opacity(0.2)))
    }
    var mobileSettings: some View {
        Form {
            Section("外观") { LanguagePicker(); Picker("主题色",selection:$s.library.preferences.accent) { ForEach(["purple","blue","green","orange","pink","teal"],id:\.self) { Text($0).tag($0) } }; Picker("显示模式",selection:$s.library.preferences.theme) { Text("跟随系统").tag("system"); Text("深色").tag("dark"); Text("浅色").tag("light") } }
            Section("电台目录") { Toggle("RadioBrowser",isOn:$s.library.preferences.radioBrowser); Toggle("Deutsia I2P 目录",isOn:$s.library.preferences.registry); Toggle("电台封面",isOn:$s.library.preferences.artwork) }
            Section("I2P") { TextField("代理主机",text:$s.library.preferences.i2pHost).textInputAutocapitalization(.never); TextField("端口",value:$s.library.preferences.i2pPort,format:.number).keyboardType(.numberPad); Text("iOS 需连接可达的 I2P HTTP 代理；不内嵌 I2P 路由器。").font(.caption).foregroundStyle(.secondary) }
            Section("自定义代理") { Toggle("强制代理",isOn:$s.library.preferences.forceProxy); MobileProxyFields(host:$s.library.preferences.proxyHost,port:$s.library.preferences.proxyPort,proto:$s.library.preferences.proxyProtocol,user:$s.library.preferences.proxyUsername,password:$s.library.preferences.proxyPassword,auth:$s.library.preferences.proxyAuthType); Text("代理失败时不回退直连。iOS 暂不支持 SOCKS4。").font(.caption).foregroundStyle(.secondary); Button("应用网络设置") { s.settingsChanged() } }
            Section("本地安全") {
                Toggle("加密本地资料库",isOn:$s.library.preferences.encrypted)
                SecureField("设置新 PIN（至少 6 位）",text:$pin).keyboardType(.numberPad)
                Button("设置 PIN") { s.setPIN(pin); pin = "" }
                if !s.library.preferences.pinHash.isEmpty { Button("锁定应用") { s.locked = true }; Button("关闭应用锁") { s.library.preferences.pinHash = ""; s.save() } }
            }
            Section("录音") { Toggle("切换电台时继续录制",isOn:$s.library.preferences.recordAcrossStations) }
            Section("导入与导出") {
                Button("导入 JSON / CSV / M3U / PLS") { importing = true }
                ForEach(["json","csv","m3u","pls"],id:\.self) { ext in Button("导出 \(ext.uppercased())") { do { document = ExportDocument(data:try exportStations(s.library.stations,ext:ext)); exportExt = ext; exporting = true } catch { s.error = error.localizedDescription } } }
                Button("管理电台类型") { manageGenres = true }
                NavigationLink("录音文件") { RecordingFiles() }
                Button("清除收听历史") { s.library.history = []; s.save() }
            }
            Section("关于 Deutsia Radio") { AboutContent() }
        }.navigationTitle("设置").onDisappear { s.save() }
    }
}
struct MobileEditor: View {
    @Environment(\.dismiss) var dismiss
    @State var station: Station
    var save: (Station)->Void
    @State var error = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("电台") { TextField("名称",text:$station.name); TextField("流媒体 URL",text:$station.streamUrl).keyboardType(.URL).textInputAutocapitalization(.never); TextField("类型",text:$station.genre); TextField("国家",text:$station.country); TextField("封面 URL",text:$station.coverArtUri).keyboardType(.URL).textInputAutocapitalization(.never); Toggle("收藏",isOn:$station.isLiked) }
                Section("网络") { Picker("连接方式",selection:$station.proxyType) { Text("直连").tag("NONE"); Text("I2P").tag("I2P"); Text("自定义代理").tag("CUSTOM") }; if station.proxyType == "CUSTOM" { MobileProxyFields(host:$station.proxyHost,port:$station.proxyPort,proto:$station.customProxyProtocol,user:$station.proxyUsername,password:$station.proxyPassword,auth:$station.proxyAuthType) } }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }.navigationTitle("编辑电台").toolbar { ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("保存") { do { _ = try validateStream(station.streamUrl); guard !station.name.isEmpty else { throw RadioError.message("请输入名称") }; save(station); dismiss() } catch { self.error = error.localizedDescription } } } }
        }
    }
}
struct MobileProxyFields: View {
    @Binding var host: String; @Binding var port: Int; @Binding var proto: String; @Binding var user: String; @Binding var password: String; @Binding var auth: String
    var body: some View {
        Picker("协议",selection:$proto) { ForEach(["HTTP","HTTPS","SOCKS5"],id:\.self) { Text($0).tag($0) } }
        TextField("主机",text:$host).textInputAutocapitalization(.never); TextField("端口",value:$port,format:.number).keyboardType(.numberPad)
        Picker("认证",selection:$auth) { Text("无").tag("NONE"); Text("Basic").tag("BASIC"); Text("Digest").tag("DIGEST") }
        TextField("用户名",text:$user).textInputAutocapitalization(.never); SecureField("密码",text:$password)
    }
}
struct MobilePlayer: View {
    @State var showTimer = false
    @EnvironmentObject var s: RadioStore
    @Environment(\.dismiss) var dismiss
    let labels = ["60","170","310","600","1k","3k","6k","12k","14k","16k"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:28) {
                    ZStack { RoundedRectangle(cornerRadius:38).fill(LinearGradient(colors:[s.accent.opacity(0.7),.indigo.opacity(0.35)],startPoint:.topLeading,endPoint:.bottomTrailing)); Image(systemName:"dot.radiowaves.left.and.right").font(.system(size:100)).foregroundStyle(.white.opacity(0.8)) }.frame(height:260).padding(.top,20)
                    VStack(spacing:10) { Text(s.current?.name ?? "Deutsia Radio").font(.title.bold()); Text(s.track.isEmpty ? s.status : s.track).foregroundStyle(.secondary) }
                    HStack(spacing:45) { Button { s.skip(-1) } label: { Image(systemName:"backward.end.fill").font(.title) }; Button { s.toggle() } label: { Image(systemName:s.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size:70)) }; Button { s.skip(1) } label: { Image(systemName:"forward.end.fill").font(.title) } }
                    Slider(value:$s.library.preferences.volume,in:0...100).onChange(of:s.library.preferences.volume) { _,_ in s.volumeChanged() }
                    HStack { Button(s.recordingURL == nil ? "开始录音" : "停止录音",systemImage:"record.circle") { s.recordCurrent() }; Spacer(); Menu("定时停止",systemImage:"moon.zzz") { ForEach([15,30,45,60,90],id:\.self) { m in Button("\(m) 分钟") { s.timerEnd = Date().addingTimeInterval(Double(m)*60) } }; Button("自定义时间…") { showTimer = true }; Button("取消定时") { s.timerEnd = nil } } }
                    if let end = s.timerEnd { Text("将在 \(end.formatted(date:.omitted,time:.shortened)) 停止").font(.caption).foregroundStyle(.secondary) }
                    Toggle("均衡器",isOn:$s.eqEnabled).onChange(of:s.eqEnabled) { _,_ in s.applyEQ() }
                    if s.eqEnabled { ForEach(0..<10,id:\.self) { i in HStack { Text(labels[i]+" Hz").font(.caption.monospaced()).frame(width:55); Slider(value:$s.bands[i],in:-20...20).onChange(of:s.bands[i]) { _,_ in s.applyEQ() } } } }
                    Button("停止播放") { s.stop() }
                }.padding(25)
            }.sheet(isPresented:$showTimer) { SleepTimerView() }.navigationTitle("正在收听").navigationBarTitleDisplayMode(.inline).toolbar { Button("完成") { dismiss() } }
        }
    }
}
struct RecordingFiles: View {
    var files: [URL] { let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Recordings"); return ((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? []).sorted { $0.lastPathComponent > $1.lastPathComponent } }
    var body: some View { List(files,id:\.self) { u in ShareLink(item:u) { Label(u.lastPathComponent,systemImage:"waveform") } }.navigationTitle("录音文件") }
}
