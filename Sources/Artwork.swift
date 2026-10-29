import SwiftUI
struct StationArtwork: View {
    @EnvironmentObject var s: RadioStore
    var station: Station
    var size: CGFloat = 60
    @State private var bytes: Data?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:size*0.23).fill(LinearGradient(colors:[s.accent.opacity(0.3),.indigo.opacity(0.15)],startPoint:.topLeading,endPoint:.bottomTrailing))
            if let bytes {
                #if os(macOS)
                if let image = NSImage(data:bytes) { Image(nsImage:image).resizable().scaledToFill() }
                #else
                if let image = UIImage(data:bytes) { Image(uiImage:image).resizable().scaledToFill() }
                #endif
            } else { Image(systemName:s.current?.streamUrl == station.streamUrl && s.playing ? "waveform" : "dot.radiowaves.left.and.right").font(.system(size:size*0.42)).foregroundStyle(s.accent) }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.23))
        .task(id:station.coverArtUri + s.networkFingerprint + String(s.library.preferences.artwork)) {
            bytes = nil
            guard s.library.preferences.artwork, !station.coverArtUri.isEmpty else { return }
            if station.coverArtUri.hasPrefix("data:image/"), let comma = station.coverArtUri.firstIndex(of:",") {
                bytes = Data(base64Encoded:String(station.coverArtUri[station.coverArtUri.index(after:comma)...])); return
            }
            guard let u = try? validateStream(station.coverArtUri), let route = try? Route.make(station:station,prefs:s.library.preferences) else { return }
            do {
                #if os(macOS)
                let data = try await Task.detached { try route.fetch(u) }.value
                #else
                let data = try await route.fetch(u)
                #endif
                try Task.checkCancellation()
                if data.count < 4_194_304 { bytes = data }
            } catch { }
        }
    }
}
