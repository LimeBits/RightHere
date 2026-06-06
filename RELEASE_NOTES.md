# RightHere 0.1.4

发布时间：2026-06-06

## 主要变化

- 更新 macOS App icon 为蓝色圆角底板 + 白色文件加号图标。
- 重新生成 `16/32/64/128/256/512/1024` 全套 AppIcon PNG 资源。
- 修复截图源图外侧白色背景/高光残留导致的 App icon 白边问题，深色背景下显示更干净。

## 已验证

- Debug build：`xcodebuild -project RightHere.xcodeproj -scheme RightHere -configuration Debug -arch arm64 build`
- 本机部署：`./deploy.sh --build --force`
- FinderSync extension 状态：`+ com.b-vibe.RightHere.Extension(0.1.4)`

## 分发包

- DMG：`dist/RightHere-0.1.4-*.dmg`

注意：当前分发包仍使用 Apple Development 证书，主要用于本机/开发设备验证。公开分发仍需要 Developer ID 签名与公证。
