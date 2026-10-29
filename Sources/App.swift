import SwiftUI
import AppKit
@main struct DeutsiaApp: App {
    @StateObject var store = RadioStore()
    var body: some Scene {
        WindowGroup { MainView().environmentObject(store).frame(minWidth: 960, minHeight: 680).preferredColorScheme(store.library.preferences.theme == "light" ? .light : store.library.preferences.theme == "system" ? nil : .dark).tint(store.accent).environment(\.locale,Locale(identifier:store.library.preferences.language == "zh" ? "zh-Hans" : store.library.preferences.language)) }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) { Button("导入电台…") { store.importFile() }.keyboardShortcut("o"); Button("导出电台…") { store.exportFile("json") }.keyboardShortcut("e") }
            CommandMenu("播放") { Button("播放 / 暂停") { store.toggle() }.keyboardShortcut(.space, modifiers: []); Button("下一个电台") { store.skip(1) }.keyboardShortcut(.rightArrow); Button("上一个电台") { store.skip(-1) }.keyboardShortcut(.leftArrow); Button("停止") { store.stop() } }
        }
        MenuBarExtra("Deutsia Radio", systemImage: "dot.radiowaves.left.and.right") {
            Text(store.current?.name ?? "Deutsia Radio"); Text(store.track)
            Button(store.playing ? "暂停" : "播放") { store.toggle() }
            Button("下一个") { store.skip(1) }; Button("停止") { store.stop() }
            Divider(); Button("退出") { NSApplication.shared.terminate(nil) }
        }
    }
}
struct MainView: View {
    @EnvironmentObject var s: RadioStore
    @State var editing: Station?
    @State var add = false
    @State var showEQ = false
    @State var showTimer = false
    @State var pin = ""
    @State var filter = ""
    @State var sortOrder = "custom"
    @State var genre = ""
    @State var manageGenres = false
    let sections = [("discover","发现电台","safari"),("library","我的电台","square.stack"),("favorites","心动收藏","heart"),("queue","播放队列","text.line.first.and.arrowtriangle.forward"),("history","最近收听","clock"),("i2p","I2P 电台","network"),("settings","设置","slider.horizontal.3")]
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar
                VStack(spacing: 0) {
                    if s.section == "settings" { SettingsView() }
                    else { content }
                    playerBar
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            if s.locked {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName:"lock.shield").font(.system(size:48)).foregroundStyle(s.accent)
                    Text("欢迎回来").font(.largeTitle.bold())
                    Text("解锁你的电台世界").foregroundStyle(.secondary)
                    SecureField("输入 PIN",text:$pin).textFieldStyle(.roundedBorder).frame(width:220).onSubmit { s.unlock(pin); pin = "" }
                    Button("解锁") { s.unlock(pin); pin = "" }.buttonStyle(.borderedProminent)
                    Button("使用 Touch ID") { s.biometricUnlock() }
                }.padding(48).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28))
            }
        }
        .onChange(of:s.networkFingerprint) { _ in s.settingsChanged() }
        .sheet(isPresented:$add) { StationEditor(station: Station()) { s.add($0) } }
        .sheet(item:$editing) { station in StationEditor(station:station) { s.update($0) } }
        .sheet(isPresented:$manageGenres) { GenreManager() }
        .sheet(isPresented:$showTimer) { SleepTimerView() }
        .sheet(isPresented:$showEQ) { EqualizerView() }
        .alert("Deutsia Radio",isPresented: Binding(get:{ s.error != nil },set:{ if !$0 { s.error = nil } })) { Button("好") { s.error = nil } } message: { Text(s.error ?? "") }
    }
    var sidebar: some View {
        VStack(alignment:.leading,spacing:28) {
            HStack(spacing:10) {
                Image(systemName:"dot.radiowaves.left.and.right").font(.title).foregroundStyle(s.accent)
                VStack(alignment:.leading,spacing:2) { Text("deutsia").font(.system(size:24,weight:.bold,design:.rounded)); Text("R A D I O").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary) }
            }.padding(.top,30)
            VStack(spacing:7) {
                ForEach(sections,id:\.0) { item in
                    Button { s.section = item.0; if item.0 == "i2p" { s.search(i2p:true) } } label: {
                        HStack(spacing:12) { Image(systemName:item.2).frame(width:20); Text(LocalizedStringKey(item.1)); Spacer(); if item.0 == "library" { Text("\(s.library.stations.count)").font(.caption) } }.font(.system(size:14,weight:s.section == item.0 ? .semibold : .regular)).padding(.horizontal,14).padding(.vertical,12).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(s.section == item.0 ? s.accent : .primary).background(s.section == item.0 ? s.accent.opacity(0.13) : Color.clear,in:RoundedRectangle(cornerRadius:12))
                }
            }
            Spacer()
            VStack(alignment:.leading,spacing:9) {
                Label("只为声音，留一点时间",systemImage:"waveform").font(.caption)
                Text("macOS · 社区移植版").font(.caption2).foregroundStyle(.tertiary)
                if !s.library.preferences.pinHash.isEmpty { Button("锁定应用",systemImage:"lock") { s.locked = true } }
            }.foregroundStyle(.secondary).padding(.bottom,22)
        }.padding(.horizontal,18).frame(width:200).background(.ultraThinMaterial)
    }
    var content: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {
                    Text(LocalizedStringKey(sections.first { $0.0 == s.section }?.1 ?? "电台")).font(.system(size:27,weight:.bold,design:.rounded))
                    if s.section != "discover" && s.section != "i2p" { Text("每一种心情，都有属于它的频率。").font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer()
                Button { add = true } label: { Label("添加电台",systemImage:"plus").padding(6) }.buttonStyle(.borderedProminent)
                Menu { Button("导入文件…") { s.importFile() }; ForEach(["json","csv","m3u","pls"],id:\.self) { ext in Button("导出 \(ext.uppercased())") { s.exportFile(ext) } } } label: { Image(systemName:"ellipsis").padding(8) }.menuStyle(.borderlessButton).frame(width:34)
            }
            if s.section == "discover" || s.section == "i2p" {
                hero
                HStack {
                    HStack { Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("搜索电台、发现好声音",text:$s.query).textFieldStyle(.plain).onSubmit { s.search(i2p:s.section == "i2p") }; if s.busy { ProgressView().controlSize(.small) } }.padding(10).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:12))
                    Button("搜索") { s.search(i2p:s.section == "i2p") }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                if s.section == "discover" {
                    HStack(spacing:10) {
                        ForEach([("热门",""),("爵士","jazz"),("古典","classical"),("电子","electronic"),("新闻","news"),("放松","ambient")],id:\.0) { title,t in
                            Button(LocalizedStringKey(title)) { s.tag = t; s.search() }.buttonStyle(.bordered).tint(s.tag == t ? s.accent : .gray)
                        }
                        Spacer()
                    }
                    HStack(spacing:12) { CountryPicker().frame(maxWidth:.infinity); StationLanguagePicker().frame(maxWidth:.infinity) }
                }
            } else {
                HStack {
                    TextField("筛选名称或类型",text:$filter).textFieldStyle(.roundedBorder)
                    Picker("排序",selection:$sortOrder) { Text("自定义").tag("custom"); Text("名称").tag("name"); Text("类型").tag("genre"); Text("最近").tag("recent") }.frame(width:150)
                    Button("管理类型") { manageGenres = true }
                }
            }
            HStack { Text(s.section == "discover" ? "为你发现" : "电台列表").font(.headline); Text("\(visible.count) 个电台").font(.caption).foregroundStyle(.secondary); Spacer(); if s.section == "queue" { Text("使用菜单调整队列顺序").font(.caption).foregroundStyle(.secondary) } }
            if visible.isEmpty {
                VStack(spacing:14) { Image(systemName:"antenna.radiowaves.left.and.right").font(.system(size:46)).foregroundStyle(s.accent.opacity(0.6)); Text(s.section == "discover" ? "世界很大，点一下开始探索" : "这里还没有电台").font(.headline); Button(s.section == "discover" ? "浏览热门电台" : "添加一个电台") { if s.section == "discover" { s.search() } else { add = true } }.buttonStyle(.bordered) }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:260),spacing:12)],spacing:12) {
                        ForEach(Array(visible.enumerated()),id:\.offset) { i,station in card(station,index:i) }
                    }.padding(.bottom,12)
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            }
        }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
    var visible: [Station] {
        let list: [Station]
        switch s.section {
        case "library": list = s.library.stations
        case "favorites": list = s.library.stations.filter(\.isLiked)
        case "queue": list = s.library.queue
        case "history": list = s.library.history
        default: list = s.results
        }
        let filtered = filter.isEmpty || ["discover","i2p"].contains(s.section) ? list : list.filter { ($0.name + $0.genre).localizedCaseInsensitiveContains(filter) }
        if s.section == "queue" || s.section == "discover" || s.section == "i2p" { return filtered }
        switch sortOrder { case "name": return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }; case "genre": return filtered.sorted { $0.genre < $1.genre }; case "recent": return filtered.sorted { $0.lastPlayedAt > $1.lastPlayedAt }; default: return filtered }

    }
    var hero: some View {
        HStack(spacing:12) {
            Image(systemName:"dot.radiowaves.left.and.right").font(.title3)
            Text(s.section == "i2p" ? "I2P · 让声音自由抵达" : "此刻，听见世界").font(.system(size:16,weight:.semibold,design:.rounded))
            Spacer()
            Text(s.section == "i2p" ? "通过你的 I2P 代理连接" : "音乐、故事与远方").font(.caption).foregroundStyle(.white.opacity(0.65))
            HStack(spacing:3) { ForEach(0..<12,id:\.self) { i in Capsule().fill(.white.opacity(0.35)).frame(width:3,height:CGFloat([10,18,12,24,16][i%5])) } }
        }.foregroundStyle(.white).padding(.horizontal,16).frame(height:48).background(LinearGradient(colors:[Color(red:0.25,green:0.13,blue:0.42),Color(red:0.15,green:0.25,blue:0.38)],startPoint:.leading,endPoint:.trailing),in:RoundedRectangle(cornerRadius:13))
    }
    func card(_ station: Station,index: Int) -> some View {
        let active = s.current?.streamUrl == station.streamUrl
        let liked = s.library.stations.first(where:{$0.streamUrl == station.streamUrl})?.isLiked ?? station.isLiked
        return VStack(alignment:.leading,spacing:10) {
            HStack(alignment:.center,spacing:10) {
                StationArtwork(station:station,size:46)
                VStack(alignment:.leading,spacing:5) { Text(station.name).font(.system(size:14,weight:.semibold)).lineLimit(1); Text(station.genre.isEmpty ? "Live Radio" : station.genre).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
                Button { s.favorite(station) } label: { Image(systemName:liked ? "heart.fill" : "heart").foregroundStyle(liked ? .pink : .secondary) }.buttonStyle(.plain)
                Menu {
                    Button("加入我的电台") { s.add(station) }; Button("加入播放队列") { s.enqueue(station) }; Button("编辑电台") { editing = station }
                    Button(s.recordingPlayers[station.id] == nil ? "录制此电台…" : "停止此电台录音") { s.recordStation(station) }
                    if s.section == "queue" {
                        Button("上移") { if index > 0 { s.library.queue.swapAt(index,index-1); s.save() } }
                        Button("下移") { if index+1 < s.library.queue.count { s.library.queue.swapAt(index,index+1); s.save() } }
                        Button("从队列移除",role:.destructive) { s.library.queue.remove(at:index); s.save() }
                    }
                    Button("删除电台",role:.destructive) { s.remove(station) }
                } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:18)
            }
            HStack {
                Circle().fill(station.network == "I2P" ? .orange : .green).frame(width:5,height:5)
                Text(station.country.isEmpty ? station.network : station.country).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(); if station.bitrate > 0 { Text("\(station.bitrate)k").font(.caption2.monospaced()).foregroundStyle(.tertiary) }
                Button { s.play(station) } label: { Image(systemName:"play.fill").font(.caption).frame(width:30,height:30).background(s.accent.opacity(0.15),in:Circle()) }.buttonStyle(.plain).foregroundStyle(s.accent)
            }
        }.padding(14).background(active ? s.accent.opacity(0.07) : Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(active ? s.accent.opacity(0.4) : Color.primary.opacity(0.06),lineWidth:1))
    }
    var playerBar: some View {
        VStack(spacing:0) {
            Rectangle().fill(LinearGradient(colors:[.purple,.indigo,s.accent.opacity(0.1)],startPoint:.leading,endPoint:.trailing)).frame(height:2)
            HStack(spacing:18) {
                Image(systemName:s.playing ? "waveform.circle.fill" : "opticaldisc.fill").font(.system(size:42)).foregroundStyle(s.accent)
                VStack(alignment:.leading,spacing:4) { Text(s.current?.name ?? "等待一段好声音").font(.subheadline.bold()).lineLimit(1); Text(s.track.isEmpty ? s.status : s.track).font(.caption).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading)
                Button { s.skip(-1) } label: { Image(systemName:"backward.end.fill") }.buttonStyle(.plain)
                Button { s.toggle() } label: { Image(systemName:s.playing ? "pause.fill" : "play.fill").font(.title3).frame(width:46,height:46).background(s.accent,in:Circle()).foregroundStyle(.white) }.buttonStyle(.plain)
                Button { s.skip(1) } label: { Image(systemName:"forward.end.fill") }.buttonStyle(.plain)
                Spacer(minLength:8)
                Button { s.recordCurrent() } label: { Image(systemName:s.recordingURL == nil ? "record.circle" : "stop.circle.fill").foregroundStyle(s.recordingURL == nil ? Color.secondary : Color.red) }.buttonStyle(.plain).help("录音 / 停止录音")
                Menu {
                    ForEach([15,30,45,60,90],id:\.self) { m in Button("\(m) 分钟后停止") { s.timerEnd = Date().addingTimeInterval(Double(m)*60) } }
                    Button("自定义时间…") { showTimer = true }
                    Button("取消定时") { s.timerEnd = nil }
                } label: { Image(systemName:s.timerEnd == nil ? "moon.zzz" : "moon.zzz.fill") }.menuStyle(.borderlessButton).frame(width:22)
                Button { showEQ = true } label: { Image(systemName:"slider.vertical.3") }.buttonStyle(.plain)
                Image(systemName:"speaker.wave.2").foregroundStyle(.secondary)
                Slider(value:$s.library.preferences.volume,in:0...100).frame(width:85).onChange(of:s.library.preferences.volume) { _ in s.volumeChanged() }
            }.padding(.horizontal,24).padding(.vertical,18).background(.bar)
            if let end = s.timerEnd { Text("定时停止：\(end.formatted(date:.omitted,time:.shortened))").font(.caption2).foregroundStyle(.secondary).padding(.bottom,6) }
        }
    }
}
struct StationEditor: View {
    @Environment(\.dismiss) var dismiss
    @State var station: Station
    var onSave: (Station)->Void
    @State var error = ""
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("编辑电台").font(.title2.bold())
            Form {
                TextField("电台名称",text:$station.name)
                TextField("流媒体 URL",text:$station.streamUrl)
                TextField("类型 / 标签",text:$station.genre)
                TextField("国家",text:$station.country)
                TextField("封面 URL",text:$station.coverArtUri)
                Toggle("收藏",isOn:$station.isLiked)
                Picker("网络",selection:$station.proxyType) { Text("直接连接").tag("NONE"); Text("I2P").tag("I2P"); Text("自定义代理").tag("CUSTOM") }
                if station.proxyType == "CUSTOM" {
                    ProxyFields(host:$station.proxyHost,port:$station.proxyPort,proto:$station.customProxyProtocol,user:$station.proxyUsername,password:$station.proxyPassword,auth:$station.proxyAuthType)
                }
            }.textFieldStyle(.roundedBorder)
            if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
            HStack { Spacer(); Button("取消") { dismiss() }; Button("保存") { do { _ = try validateStream(station.streamUrl); guard !station.name.isEmpty else { throw RadioError.message("请输入电台名称") }; onSave(station); dismiss() } catch { self.error = error.localizedDescription } }.buttonStyle(.borderedProminent) }
        }.padding(30).frame(width:500)
    }
}
struct ProxyFields: View {
    @Binding var host: String; @Binding var port: Int; @Binding var proto: String; @Binding var user: String; @Binding var password: String; @Binding var auth: String
    var body: some View {
        Picker("代理协议",selection:$proto) { ForEach(["HTTP","HTTPS","SOCKS4","SOCKS5"],id:\.self) { Text($0).tag($0) } }
        TextField("主机",text:$host); TextField("端口",value:$port,formatter:NumberFormatter())
        Picker("认证",selection:$auth) { ForEach(["NONE","BASIC","DIGEST"],id:\.self) { Text($0).tag($0) } }
        TextField("用户名",text:$user); SecureField("密码",text:$password)
        if proto == "SOCKS4" { Text("SOCKS4 使用本地 DNS；需要远端 DNS 请使用 SOCKS5。").font(.caption).foregroundStyle(.orange) }
    }
}
struct SettingsView: View {
    @EnvironmentObject var s: RadioStore
    @State var newPIN = ""
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                Text("设置").font(.system(size:30,weight:.bold,design:.rounded))
                Form {
                    Section("外观") {
                        LanguagePicker()
                        Picker("主题色",selection:$s.library.preferences.accent) { Text("紫色").tag("purple"); Text("蓝色").tag("blue"); Text("绿色").tag("green"); Text("橙色").tag("orange"); Text("粉色").tag("pink"); Text("青色").tag("teal") }
                        Picker("显示模式",selection:$s.library.preferences.theme) { Text("跟随系统").tag("system"); Text("深色").tag("dark"); Text("浅色").tag("light") }
                    }
                    Section("电台目录与隐私") {
                        Toggle("RadioBrowser 普通电台目录",isOn:$s.library.preferences.radioBrowser)
                        Toggle("Deutsia I2P 电台目录",isOn:$s.library.preferences.registry)
                        Toggle("加载电台封面",isOn:$s.library.preferences.artwork)
                        Text("电台目录请求会连接对应服务。无云同步、无统计遥测。").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("I2P HTTP 代理") { TextField("I2P 主机",text:$s.library.preferences.i2pHost); TextField("端口",value:$s.library.preferences.i2pPort,formatter:NumberFormatter()); Text("请先运行 Mac 版 I2P / i2pd，默认端口 4444。").font(.caption).foregroundStyle(.secondary) }
                    Section("强制自定义代理") {
                        Toggle("所有外网请求通过代理",isOn:$s.library.preferences.forceProxy)
                        ProxyFields(host:$s.library.preferences.proxyHost,port:$s.library.preferences.proxyPort,proto:$s.library.preferences.proxyProtocol,user:$s.library.preferences.proxyUsername,password:$s.library.preferences.proxyPassword,auth:$s.library.preferences.proxyAuthType)
                        Text("I2P 电台使用专属 I2P 代理。代理连接失败时不会回退直连。").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("本地安全") {
                        Toggle("加密本地电台库与历史记录",isOn:$s.library.preferences.encrypted)
                        Text("AES-256-GCM 加密，密钥保存在 macOS 钥匙串；代理密码存在时自动加密整个资料库。").font(.caption).foregroundStyle(.secondary)
                        SecureField("新 PIN（至少 6 位）",text:$newPIN)
                        HStack { Button("设置 / 更新 PIN") { s.setPIN(newPIN); newPIN = "" }; if !s.library.preferences.pinHash.isEmpty { Button("关闭应用锁") { s.library.preferences.pinHash = ""; s.save() } } }
                    }
                    Section("录音") { Toggle("切换电台时继续录制原电台",isOn:$s.library.preferences.recordAcrossStations) }
                    Section("资料管理") {
                        HStack { Button("导入电台…") { s.importFile() }; Button("导出 JSON…") { s.exportFile("json") }; Button("清除历史记录") { s.library.history = []; s.save() } }
                    }
                    Section("关于") { AboutContent() }
                }.formStyle(.grouped)
                Button("保存网络与隐私设置") { s.settingsChanged() }.buttonStyle(.borderedProminent)
                Text("应用网络设置时会停止播放和录音。").font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
    }
}
struct EqualizerView: View {
    @EnvironmentObject var s: RadioStore
    @Environment(\.dismiss) var dismiss
    let labels = ["60","170","310","600","1k","3k","6k","12k","14k","16k"]
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Text("均衡器").font(.title2.bold()); Spacer(); Toggle("启用",isOn:$s.eqEnabled).toggleStyle(.switch) }
            ForEach(0..<10,id:\.self) { i in HStack { Text(labels[i]+" Hz").font(.caption.monospaced()).frame(width:60,alignment:.leading); Slider(value:$s.bands[i],in:-20...20); Text(String(format:"%+.0f dB",s.bands[i])).font(.caption.monospaced()).frame(width:50) } }
            HStack { Button("重置") { s.bands = [Double](repeating:0,count:10) }; Spacer(); Button("完成") { dismiss() }.buttonStyle(.borderedProminent) }
        }.padding(30).frame(width:480).onChange(of:s.bands) { _ in s.applyEQ() }.onChange(of:s.eqEnabled) { _ in s.applyEQ() }
    }
}
