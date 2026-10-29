import Foundation
final class Player {
    private var instance: OpaquePointer?
    private var media: OpaquePointer?
    private var player: OpaquePointer?
    init() throws {
        #if os(macOS)
        let plugins = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/vlc/plugins").path
        if getenv("VLC_PLUGIN_PATH") == nil { setenv("VLC_PLUGIN_PATH", plugins, 1) }
        #endif
        let args = ["--no-video", "--no-video-title-show", "--no-osd", "--no-lua", "--no-metadata-network-access", "--no-media-library", "--quiet", "--network-caching=1500"]
        let c = args.map { strdup($0) }; defer { c.forEach { free($0) } }
        instance = c.withUnsafeBufferPointer { b in
            b.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: c.count) { libvlc_new(Int32(c.count), $0) }
        }
        guard instance != nil else { throw RadioError.message("无法启动 VLC 播放引擎") }
    }
    deinit { stop(); if let instance { libvlc_release(instance) } }
    func play(_ url: URL, volume: Double, recording: URL? = nil) throws {
        stop()
        guard let instance, let m = libvlc_media_new_location(instance, url.absoluteString) else { throw RadioError.message("无法加载音频流") }
        media = m
        libvlc_media_add_option(m, ":no-video")
        if let recording {
            let path = recording.path.replacingOccurrences(of: "'", with: "")
            libvlc_media_add_option(m, ":sout=#duplicate{dst=display,dst=std{access=file,mux=ts,dst='\(path)'}}")
            libvlc_media_add_option(m, ":sout-keep")
        }
        guard let p = libvlc_media_player_new_from_media(m) else { stop(); throw RadioError.message("无法创建播放器") }
        player = p
        libvlc_audio_set_volume(p, Int32(volume))
        guard libvlc_media_player_play(p) == 0 else { stop(); throw RadioError.message("播放失败") }
    }
    func stop() {
        if let player { libvlc_media_player_stop(player); libvlc_media_player_release(player) }; player = nil
        if let media { libvlc_media_release(media) }; media = nil
    }
    func pause(_ paused: Bool) { if let player { libvlc_media_player_set_pause(player, paused ? 1 : 0) } }
    func volume(_ v: Double) { if let player { libvlc_audio_set_volume(player, Int32(v)) } }
    var state: Int { guard let player else { return 0 }; return Int(libvlc_media_player_get_state(player)) }
    var title: String {
        guard let media, let ptr = libvlc_media_get_meta(media, 12) else { return "" }
        defer { libvlc_free(ptr) }; return String(cString: ptr)
    }
    func equalizer(_ bands: [Double], enabled: Bool) {
        guard let player else { return }
        guard enabled, let eq = libvlc_audio_equalizer_new() else { libvlc_media_player_set_equalizer(player, nil); return }
        for (i, v) in bands.enumerated() { libvlc_audio_equalizer_set_amp_at_index(eq, Float(v), UInt32(i)) }
        libvlc_media_player_set_equalizer(player, eq); libvlc_audio_equalizer_release(eq)
    }
}
