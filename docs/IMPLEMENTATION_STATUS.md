# Deutsia Radio · Apple 平台社区移植

移植与界面设计：**Billson**  
AI 辅助开发：**OpenAI Codex**  
使用模型：**gpt-6.1-sol**

原作者：[deutsia](https://github.com/deutsia)  
原项目：[deutsia/deutsia-radio](https://github.com/deutsia/deutsia-radio)  
基于 Android v1.8.1，源码提交 `38499d6f2555a80de4b7df1b1073f3e0cdb1f124`，Apache License 2.0。

这是独立的原生 Swift / SwiftUI 社区移植。Android 平台组件不能直接在 Apple 平台运行，界面、播放、文件访问和安全存储均已重新实现。当前交付为 **0.1.1 预览版**，不能据此宣称已实现并验证原项目所有非 Tor 功能的百分之百等价。

## Mac 使用

`dist/Deutsia Radio.app`：Apple Silicon，macOS 13 或更新版本。安装镜像生成在 `dist/`，拖到“应用程序”即可。也可以在当前工作区直接启动应用。

当前为 **本机 ad-hoc 签名**，不是 Apple ID 开发证书签名，也未经 Apple 公证。本机未找到有效的代码签名身份。开发签名需要兼容的完整 Xcode 与开发团队。

界面包含侧边导航、渐变发现区、电台封面卡片、常驻播放器、深浅色模式及六种主题色。设置和系统“关于”中均包含原作者页面、Billson、Codex 与使用模型署名。

## 已实现的主要功能

- 普通 HTTP / HTTPS 电台播放，以及 libVLC 支持的音频格式。
- RadioBrowser 发现、名称搜索、类型快捷筛选。
- **国家选单**：从目录获取可选国家，默认全部，无需手动输入。
- **电台语言选单**：全部语言、全部汉语、普通话／简体中文、粤语和目录提供的其他语言；与国家、名称、类型条件组合。
- “简体中文”不是电台音频语言，筛选实际映射普通话和中文标签；“全部汉语”合并 Chinese、Mandarin、Cantonese、中文、粤语等目录标签。结果依赖社区目录标注，可能存在误标或漏标。
- 我的电台、收藏、最近收听、自定义播放队列、前后切台。
- 自定义电台、编辑、类型重命名／删除、名称／类型／最近排序。
- M3U、PLS 和 HLS 清单解析；HLS 变体、片段、密钥地址通过同一播放通道访问。
- DASH 清单解析与地址转发，保留动态片段模板。
- 录音、多个电台分别录音、切台时继续录音选项。当前输出 MPEG-TS（`.ts`）。
- 10 段均衡器、音量、预设睡眠时间与 1 分钟至 12 小时的自定义定时。
- JSON、CSV、M3U、PLS 电台导入／导出；兼容上游常用导出字段。
- I2P HTTP 代理；Mac HTTP、HTTPS、SOCKS4、SOCKS5 自定义代理，支持代理认证配置。
- 强制代理、代理失败不自动直连；SOCKS5 使用代理端 DNS。SOCKS4 按协议使用本地 DNS。
- 可关闭目录与封面网络请求；封面走所配置的网络通道。
- PIN 应用锁、生物识别解锁入口、AES-256-GCM 本地资料库加密、系统钥匙串保存密钥。
- Mac 菜单栏控制、系统媒体控制；iOS 后台音频与锁屏媒体控制配置。
- 17 种语言的基础控件翻译，复用原项目译文；**新增界面与说明文案尚未全部本地化，会回退英文或中文**。

Tor 管理、Tor 代理模式、Tor 目录和 `.onion` 电台均已移除／拒绝。Android Auto 为 Android 专属功能，不存在直接可移植的 macOS / iOS 实现；本版提供 Apple 平台媒体控制，尚未实现 CarPlay。

## 网络与本地数据

Mac 普通流媒体、录音和清单子请求经过仅监听 `127.0.0.1` 的本机播放转发器；转发器使用系统 curl 执行所选代理策略。更改网络设置会终止原播放与录音，取消旧目录／封面请求。

I2P 需要另外运行用户自己的 I2P / i2pd 路由器，默认代理 `127.0.0.1:4444`。iOS 需要可达的 I2P HTTP 代理，不包含内嵌路由器。

普通启动、未加密的资料库读取与保存不访问钥匙串。只有读取已有加密资料库，或需要保存加密数据／代理密码时，才读取／创建本应用专属的 `com.deutsia.mac.vault / local-encryption-key` 条目，不查询 Apple ID 或其他应用的密码。

本地数据：`~/Library/Application Support/DeutsiaRadioMac/library.dat`。加密密钥保存在当前用户钥匙串。启用加密，或保存代理密码时，会加密整个资料库。PIN 使用带随机盐的 PBKDF2-HMAC-SHA256（200,000 次）。电台导出文件不包含代理密码。

## 验证状态与已知边界

- 35 项核心检查通过：加密往返、防篡改、四种文件格式、Tor URL 拒绝、HLS 地址、DASH 模板／初始化与 Tor 拒绝、代理失败保护、过期网络策略、语言别名与组合查询等。
- I2P 公开目录端点已核对并能读取条目（不等于已验证 I2P 音频连接）。
- Mac 实际界面已启动检查，目录可返回电台，在线电台进入播放状态且可暂停。
- 在线目录 → 本机转发 → libVLC 播放 → 录音 → 停止的集成测试通过。
- HLS 主清单 → 相对变体 → 相对片段 → 播放的集成测试通过。
- 深层代码签名完整性检查通过（ad-hoc）。
- **尚未做真实 I2P 网络、全部代理协议／认证组合、全部电台编解码器的端到端验证。** DASH 当前已做清单级验证，尚无真实在线 DASH 电台的端到端验证。
- Touch ID / Face ID 需要设备本人验证，尚未代用户执行验证。
- **iOS 目前是源码与工程交付，不是已验证的可安装 IPA。** 工程结构与 Swift 语法已检查，共用核心代码已在 Mac 编译；缺少 iOS SDK，未完成 iOS 全量编译、设备验证及 Apple ID 签名。iOS SOCKS4 暂不支持，会明确报错；HTTP／HTTPS／SOCKS5 使用系统代理接口，认证兼容性仍需真机验证。
- 预览版仍需继续补齐／验证上述差异，不能将“保留非 Tor 功能”的移植目标视为已经全部完成。

## Mac 重建

需要 Apple Command Line Tools 与官方 VLC 3.0.21 Apple Silicon 播放库。

```sh
VLC_SOURCE="/path/to/VLC.app/Contents/MacOS" bash build-mac.sh
bash Tests/run-core.sh
bash Tests/run-integration.sh
```

`build-mac.sh` 在已有应用播放库可用时直接复用；首次构建需指定 `VLC_SOURCE`。构建会去掉与广播播放无关的蓝光 Java 文件及原发行包插件缓存，重签动态库和应用。

VLC 官方二进制：[VLC 3.0.21 arm64](https://download.videolan.org/pub/videolan/vlc/3.0.21/macosx/vlc-3.0.21-arm64.dmg)。原始源码和许可证见 `NOTICE` 与 `Resources/VLC-COPYING*.txt`。播放库保持动态链接，可以用兼容的用户构建替换。

## iOS 后续编译与当前 Apple ID 自签

完整 Xcode 的版本必须与使用的 macOS 兼容。官方兼容要求：https://developer.apple.com/xcode/system-requirements

1. 安装兼容的完整 Xcode 和 iOS SDK，完成本人登录与所需许可流程。
2. Xcode → Settings → Accounts，使用当前 Apple ID；在项目 Signing & Capabilities 选择其 Personal Team / 开发团队。
3. 安装 CocoaPods。`iOS/Podfile` 固定官方 `MobileVLCKit 3.6.0`，以保持 VLC 3 C API 兼容。
4. 在 `iOS` 目录运行 `pod install`，打开生成的 `DeutsiaRadio.xcworkspace`，选择自己的 iPhone 构建运行。开启开发者模式并信任此 Mac 需由设备本人处理。
5. 或运行 `TEAM_ID=你的团队ID bash build-ios.sh`；通过 `DEVICE_UDID` 可选择已配对设备安装。

免费 Personal Team 的设备安装描述文件通常 7 天到期，需要重新签名安装；具体规则以 Apple 当前账户要求为准：https://developer.apple.com/help/account/basics/about-your-developer-account

本项目不包含 Apple ID 密码、签名私钥或描述文件。iOS 签名与设备验证尚未完成。

## 0.1.1 界面更新

发现页的宣传横幅缩为 48 点高，减少标题与筛选区留白；电台卡片改为紧凑布局，列表使用剩余可用高度。保留国家、语言与类型筛选，并加入新设计的紫色收音机图标（Mac / iOS）。实际启动检查可在原窗口完整显示两排电台，并恢复原先的播放。
