# Third-party components

## deutsia radio

Original author: deutsia, copyright 2025. Original project: https://github.com/deutsia/deutsia-radio

Reference release: v1.8.1; revision: 38499d6f2555a80de4b7df1b1073f3e0cdb1f124.

License: Apache-2.0, included in LICENSE. Original translations are reused. Apple-platform components are a separate native implementation. Modified implementation and interface attribution: Billson, with OpenAI Codex assistance (model gpt-6.1-sol).

## VideoLAN VLC 3.0.21 (macOS)

The macOS app dynamically links libVLC/libvlccore and includes playback plugins from the official Apple Silicon VLC distribution. libVLC is LGPL-2.1-or-later; the VLC distribution and individual modules may be covered by GPL-2.0-or-later and other component-specific licenses. Those licenses remain applicable to their respective components.

- Official binary: https://download.videolan.org/pub/videolan/vlc/3.0.21/macosx/vlc-3.0.21-arm64.dmg
- Corresponding upstream release source: https://download.videolan.org/pub/videolan/vlc/3.0.21/vlc-3.0.21.tar.xz
- Licensing texts: Resources/VLC-COPYING.txt and Resources/VLC-COPYING-LIB.txt.
- The matching upstream VLC release source archive is also provided with the preview release.

The libraries are dynamically linked and may be replaced with compatible user builds. Build the application against replacement libraries using build-mac.sh. This repository's Apache license does not relicense VLC binaries or plugins.

## MobileVLCKit 3.6.0 (iOS dependency)

Not vendored in the source repository and not distributed as an iOS binary here. CocoaPods resolves the official fixed-version dependency for an iOS build.

- Project and source: https://code.videolan.org/videolan/VLCKit
- Official package: https://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-3.6.0-c73b779f-dd8bfdba.tar.xz
- Podspec SHA-256: 1a5077beeb7bf943a3fbbb91523752e50a10d490a3046cb9808d906784ddbc36
- License: LGPL-2.1 as declared by the package; see the original package's COPYING.txt and component notices.

## App icon

The v2 purple radio icon was generated with OpenAI image generation for this project, then resized into platform icon assets. Legacy icon-generation scripts/assets may be retained for development history; the current application uses Resources/AppIcon.icns and iOS/Assets.xcassets/AppIcon.appiconset.
