# RightHere 0.1.9

发布时间：2026-07-31

## 这一版的定位

RightHere 0.1.9 是修复 Sparkle 更新通道配置的正式分发版本。用于普通用户安装验证的包必须是：

- Universal Binary：`arm64 + x86_64`
- Developer ID Application 签名
- Apple notarization 公证通过
- stapler 已绑定公证票据
- Gatekeeper 验证通过

Apple Development 签名包和 ad-hoc ZIP 只用于开发机快速验证，不再作为普通新用户安装验证依据。

## 主要变化

- 修复 0.1.8 包内缺少 Sparkle `SUFeedURL` / `SUPublicEDKey` 配置，导致「检查更新」弹出英文错误的问题。
- 修复 appcast 生成时只有相对 DMG 文件名、缺少 EdDSA 签名校验的问题。
- appcast 生成脚本现在会强制校验 `sparkle:edSignature` 和 HTTPS 下载地址，避免再次上传无效更新源。
- RightHere 启动时会自动注册当前 App，并尝试启用 `com.LimeBits.RightHere.Extension`，改善普通用户拖拽安装后 Finder 右键菜单不出现的问题。
- FinderSync extension 增加 Documents 写入权限，修复「下载」可新建文件但「文稿」有菜单却无反应的问题。
- 安装脚本刷新 LaunchServices 与 Dock 图标缓存，改善 Launchpad 首次安装后图标短暂透明的问题。
- 接入 Sparkle 2 更新框架，后续正式包可通过 App 内「检查更新」下载、验证并安装新版本。
- 新增 `Scripts/package-developer-id.sh`，统一执行归档、Developer ID 导出、DMG 打包、DMG 签名、公证和 stapler 绑定。
- 新增 `Scripts/notarize.sh`，复用 `righthere-notary` keychain profile 完成公证和 Gatekeeper 验证。
- 正式分发脚本强制校验主 App 和 FinderSync extension 都包含 `arm64` 与 `x86_64`。
- Bundle ID 切换为 `com.LimeBits.RightHere`，FinderSync extension 切换为 `com.LimeBits.RightHere.Extension`，App Group 切换为 `group.com.LimeBits.RightHere`。
- 安装脚本会停用旧 bundle id 的 FinderSync 状态、启用新扩展并重启 Finder。
- 设置页只在系统明确返回未启用或未注册时显示 Finder 扩展提示，不再展示容易误导的“暂时不可读”状态。
- 启动时移除 Finder 扩展未就绪弹窗，降低首次安装干扰。
- 补齐标准 macOS AppIcon 10 个槽位，改善 Launchpad 图标首次透明或延迟刷新的问题。
- 菜单栏图标居中绘制并略微放大，改善视觉尺寸和垂直位置。

## 正式打包命令

```bash
cd /Users/bruce/Desktop/b-vibe/RightHere
RIGHTHERE_DEVELOPMENT_TEAM=WV6JA6UHLN \
Scripts/package-developer-id.sh
```

脚本会从 `.dev.vars` 读取 `SPARKLE_PUBLIC_ED_KEY`。成功后会输出 `dist/RightHere-0.1.9-build6-*.dmg` 和对应 `.sha256`。这个 DMG 才用于 Intel / Apple Silicon 新电脑和普通新用户验证。

生成 Sparkle appcast：

```bash
Scripts/generate-appcast.sh
```

脚本会从 `.dev.vars` 读取 `SPARKLE_GENERATE_APPCAST`，并要求 Sparkle 私钥可从钥匙串读取；生成结果必须包含 EdDSA 签名和 GitHub HTTPS 下载地址。

## 验证重点

- 在 Intel Mac 上双击 DMG 安装后，RightHere 能正常打开。
- Finder 右键菜单能出现「新建文件」。
- 首次安装后不再出现误导性的 Finder 扩展授权弹窗。
- Launchpad 图标能正常显示。
- 菜单栏图标大小和位置接近系统菜单栏图标。
