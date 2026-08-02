# RightHere

RightHere 是一个 macOS Finder 右键增强工具。它让你在 Finder 里更快完成三件事：新建文件、在当前目录打开终端、快速打开常用文件或隐藏路径。

适合经常在 Finder、终端和配置文件之间来回切换的人。

## 功能亮点

### 右键新建文件

在 Finder 右键菜单中直接新建常用文件，不用先打开对应 App 再另存为。

- 支持文本、Markdown、Word、Excel、PowerPoint 等常用文件类型
- 支持自定义模板，把自己的模板文件加入右键菜单
- 可在设置里管理显示哪些文件类型，保持右键菜单清爽
- 自动处理重名文件，例如 `新建文档`、`新建文档 (2)`

### 在此处打开终端

在 Finder 当前目录快速打开终端，省去复制路径和手动 `cd`。

- 支持文件夹空白处右键
- 支持桌面空白处右键
- 支持右键文件夹时打开该文件夹所在位置
- 避免干扰文件右键菜单，减少和系统“打开方式”的冲突

### 快捷打开

把常用文件、文件夹或隐藏路径加入 Finder 右键菜单，一键直达。

- 适合快速打开 `~/.zshrc`、`/etc/hosts`、`~/.codex` 等隐藏配置路径
- 支持添加文件、文件夹和手动输入路径
- 可单独启用、隐藏、重命名或删除每个快捷打开项
- 由主 App 执行打开，减少 FinderSync extension 沙盒权限带来的限制

### 轻量设置

所有右键菜单能力都可以在设置里集中管理。

- 管理新建文件模板
- 管理右键工具入口
- 控制哪些项目出现在 Finder 右键菜单中
- 菜单栏常驻，不打断当前工作流

## 安装

从 [GitHub Releases](https://github.com/LimeBits/RightHere/releases) 下载最新 DMG。

安装后把 `RightHere.app` 拖到“应用程序”，然后打开一次 RightHere。App 会尝试注册并启用 Finder 扩展；如果 Finder 右键菜单没有立刻出现，退出并重新打开 Finder，或重启 Finder 后再试。

系统要求：

- macOS 12.0 或更高版本
- Intel Mac 和 Apple Silicon Mac

## 使用

### 新建文件

在 Finder 文件夹空白处或桌面空白处右键，选择：

```text
新建文件 -> 文本文件 / Markdown / Word 文档 / ...
```

### 管理模板

打开 RightHere 设置，在“模板”页勾选要显示在右键菜单里的文件类型。

首次打开模板文件夹时，RightHere 会初始化默认模板：

```text
template.txt
template.md
template.docx
template.xlsx
template.pptx
```

你可以直接编辑这些模板，也可以添加新的 `template.<扩展名>` 文件，例如：

```text
template.rtf
template.csv
template.json
template.swift
```

刷新设置页后，新模板会出现在列表中，勾选后会显示在 Finder 右键菜单中。

### 打开终端

在 Finder 文件夹空白处或桌面空白处右键，选择：

```text
在此处打开 -> 终端
```

### 快捷打开

打开 RightHere 设置，在“工具”页添加常用文件、文件夹或路径。之后可以在 Finder 右键菜单中选择：

```text
快捷打开 -> 你的文件或文件夹
```

适合加入：

```text
~/.zshrc
/etc/hosts
~/.codex
~/Library/Application Support
```

## 更新与反馈

菜单栏选择 **帮助与反馈 -> 检查更新...** 可检查新版本。

菜单栏选择 **帮助与反馈 -> 反馈问题...** 可打开预填诊断信息的 GitHub Issue 页面。也可以选择 **复制诊断信息**，再手动粘贴到 Issue 中。

RightHere 不收集 analytics，不会自动上传模板或文件内容。详见 [PRIVACY.md](PRIVACY.md)。

## 本地开发

克隆仓库后，用 Xcode 打开 `RightHere.xcodeproj`。如果要在自己的机器上长期调试，请在 Xcode 里把主 App 和 FinderSync extension 的 Team、Bundle ID、App Group 改成你自己的值。

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

开源仓库不会提交个人 Team ID。由于 RightHere 使用 App Group 和 FinderSync extension，本机安装调试需要开发签名。可以临时通过环境变量传入自己的 Team ID：

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --force
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --universal --force
```

也可以在 Xcode 的 Signing & Capabilities 中为两个 target 选择自己的 Team。这样会修改本地工程文件，提交前请确认没有把个人 Team ID 提交到开源仓库。

## 正式分发

普通用户安装包应使用 Developer ID 签名、公证并 staple 的 Universal DMG。GitHub Actions 自动生成的 DMG 只适合 CI/打包流程验证，不适合新电脑直接安装验证 FinderSync。

正式分发包使用：

```bash
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

RightHere 使用 Sparkle 2 作为 App 内更新框架。每次上传 DMG 时，用 `Scripts/generate-appcast.sh` 生成并上传 `appcast.xml` 到同一个 GitHub Release。

## 常见问题

### Finder 右键菜单没有出现怎么办？

先确认 RightHere 已经打开过一次。然后可以运行：

```bash
./Scripts/doctor.sh
```

如果扩展已经注册但菜单没有出现，重启 Finder 后再试：

```bash
killall Finder
```

### 为什么需要 FinderSync extension？

macOS 的 Finder 右键菜单扩展需要通过 FinderSync extension 实现。RightHere 主 App 负责设置、模板和快捷打开请求，FinderSync extension 负责把菜单显示到 Finder 里。

### 为什么快捷打开由主 App 执行？

FinderSync extension 运行在沙盒里，直接打开用户主目录、隐藏路径或部分系统路径时容易受限。RightHere 会先把请求写入 App Group，再唤起主 App 执行打开，稳定性更好。

## 目录结构

```text
RightHere/              主 App（SwiftUI 设置界面）
RightHereExtension/     FinderSync Extension
Scripts/                打包、安装和诊断脚本
deploy.sh               一键本机部署
monitor.sh              实时日志监控
DEVLOG.md               开发踩坑记录
```
