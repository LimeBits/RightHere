# RightHere

RightHere 是一个 macOS Finder 右键「新建文件」扩展。安装后可以在 Finder 的右键菜单里快速创建 txt、Markdown、Word、Excel、PowerPoint 或自定义模板文件。

## 功能

- Finder 右键菜单「新建文件」
- 默认支持 txt / Markdown / Word / Excel / PowerPoint
- 菜单栏设置入口，可勾选要显示的模板类型
- 自定义模板：在模板目录中放置 `template.rtf`、`template.json` 等文件即可扩展类型
- 自动文件名去重，例如 `新建文档`、`新建文档 (2)`
- 本机开发部署脚本和基础诊断脚本

## 系统要求

- macOS 12.0 或更高版本
- Intel Mac 和 Apple Silicon Mac
- Xcode 15 或更高版本（本地开发）

> 当前目标是 macOS 12+ Universal Binary（`arm64` + `x86_64`）。由于 FinderSync extension 依赖系统扩展机制，不同 macOS 版本仍建议实机验证。

## 本地开发

克隆仓库后，用 Xcode 打开 `RightHere.xcodeproj`。如果你要在自己的机器上长期调试，请在 Xcode 里把主 App 和 FinderSync extension 的 Team、Bundle ID、App Group 改成你自己的值。

常用命令：

```bash
# 本机架构 Debug build + 安装到 /Applications + 启用扩展
./deploy.sh --build --force

# Universal Binary Debug build（arm64 + x86_64）
./deploy.sh --build --universal --force

# 查看本机开发环境、安装状态和 FinderSync 状态
./Scripts/doctor.sh

# 实时查看 FinderSync extension 日志
./monitor.sh
```

开源仓库不会提交个人 Team ID。由于 RightHere 使用 sandbox、App Group 和 FinderSync extension，本机安装调试仍然需要开发签名。你可以临时通过环境变量传入自己的 Team ID：

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --force
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --universal --force
```

也可以在 Xcode 的 Signing & Capabilities 中为两个 target 选择自己的 Team。这样会修改本地工程文件，提交前请确认没有把个人 Team ID 提交到开源仓库。

当设置了 `DEVELOPMENT_TEAM` 时，脚本会自动给 `xcodebuild` 传入 `-allowProvisioningUpdates`，让 Xcode 尝试创建或更新本机调试需要的 provisioning profile。

## 模板

首次打开模板文件夹时，RightHere 会初始化默认模板：

- `template.txt`
- `template.md`
- `template.docx`
- `template.xlsx`
- `template.pptx`

你可以直接编辑这些文件。也可以添加新的 `template.<扩展名>` 文件，例如：

```text
template.rtf
template.csv
template.json
template.swift
```

刷新设置页后，新模板会出现在列表里，勾选后会显示在 Finder 右键菜单中。

## 更新与反馈

菜单栏选择 **帮助与反馈 -> 检查更新...** 可读取 GitHub Releases 并提示是否存在新版本。RightHere 不会自动下载或自动安装更新。

菜单栏选择 **帮助与反馈 -> 反馈问题...** 可打开预填诊断信息的 GitHub Issue 页面。也可以选择 **复制诊断信息**，再手动粘贴到 Issue 中。

RightHere 不收集 analytics，不会自动上传模板或文件内容。详见 [PRIVACY.md](PRIVACY.md)。

项目主页：

```text
https://github.com/LimeBits/RightHere
```

## 打包

开发调试可以使用：

```bash
./Scripts/package-app.sh --build --universal
./Scripts/package-dmg.sh --build
```

`package-app.sh` 默认保留 Xcode build 产物的签名，不写死任何个人证书。如果你确实需要重签，可以显式传入：

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./Scripts/package-app.sh --build --universal
```

如果 Release build 也需要指定本地 Team：

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./Scripts/package-app.sh --build --universal
```

## 公开分发状态

RightHere 0.1.8 起，公开新用户验证只使用 Developer ID 分发链路：

1. Apple Developer Program
2. Developer ID Application 证书
3. 主 App 和 FinderSync extension 正式签名
4. Apple notarization
5. stapler 绑定公证票据
6. Gatekeeper 验证

GitHub Actions 自动生成的 DMG 只适合 CI/打包流程验证，不适合新电脑直接安装验证 FinderSync。普通新用户验证请使用本机 Developer ID 签名、公证并 staple 后的 Universal DMG。

正式分发包使用：

```bash
SPARKLE_PUBLIC_ED_KEY="你的 Sparkle 公钥" \
RIGHTHERE_DEVELOPMENT_TEAM=YOURTEAMID \
./Scripts/package-developer-id.sh
```

首次使用前需要在 Xcode 里登录有效 Apple Developer 账号，并准备 notarytool 凭据：

```bash
xcrun notarytool store-credentials "righthere-notary" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password"
```

RightHere 使用 App Group 和 FinderSync extension，因此 Developer ID 导出还需要主 App 与 extension 都具备匹配的 Developer ID provisioning profile。正式分发脚本会校验主 App 和 FinderSync extension 均为 Universal Binary（`arm64 + x86_64`）。

RightHere 使用 Sparkle 2 作为 App 内更新框架。首次正式接入前，需要用 Sparkle 的 `generate_keys` 生成 EdDSA key，把公钥传给 `SPARKLE_PUBLIC_ED_KEY`；后续每次上传 DMG 时，用 `Scripts/generate-appcast.sh` 生成并上传 `appcast.xml` 到同一个 GitHub Release。

## 常见问题

**Finder 右键菜单没有出现怎么办？**

先运行 `./Scripts/doctor.sh` 查看 extension 是否注册。然后确认 RightHere 已启动、Finder 已重启，并在系统设置的扩展/Finder 扩展里启用 RightHere。

**为什么没有 Developer ID 证书也能本地调试？**

Xcode 可以用本机开发签名运行和调试。Developer ID 主要用于把 App 稳定分发给其他机器，并通过 Gatekeeper。

**为什么要修改 Bundle ID 和 App Group？**

App Group 必须和你的开发者账号、签名配置匹配。多人开源协作时，不能共用原作者的个人 Team ID。

## 目录结构

```text
RightHere/              主 App（SwiftUI 设置界面）
RightHereExtension/     FinderSync Extension
Scripts/                打包、安装和诊断脚本
deploy.sh               一键本机部署
monitor.sh              实时日志监控
DEVLOG.md               开发踩坑记录
```
