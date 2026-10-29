import SwiftUI
struct AboutContent: View {
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Deutsia Radio · Apple 平台社区移植版").font(.headline)
            Text("原作者：deutsia")
            Link("原作者 GitHub 主页",destination:URL(string:"https://github.com/deutsia")!)
            Link("原项目 deutsia/deutsia-radio",destination:URL(string:"https://github.com/deutsia/deutsia-radio")!)
            Text("移植与界面设计：Billson")
            Text("AI 辅助开发：OpenAI Codex")
            Text("使用模型：gpt-6.1-sol")
            Text("基于 Android v1.8.1 · Apache License 2.0\n此为独立社区移植，已移除 Tor。\n播放引擎：VideoLAN VLC / MobileVLCKit，遵循其各自许可证。").font(.caption).foregroundStyle(.secondary)
            Link("播放引擎源码与许可证",destination:URL(string:"https://code.videolan.org/videolan/VLCKit")!)
        }
    }
}
