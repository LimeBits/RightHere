<div align="center">

# RightHere

**Finder 右键菜单增强工具，让 Finder 做更多事**

[![下载](https://img.shields.io/github/v/release/LimeBits/RightHere?label=%E4%B8%8B%E8%BD%BD&color=blue)](https://github.com/LimeBits/RightHere/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B-black)](https://github.com/LimeBits/RightHere/releases/latest)
[![架构](https://img.shields.io/badge/%E6%9E%B6%E6%9E%84-Intel%20%7C%20Apple%20Silicon-lightgrey)](https://github.com/LimeBits/RightHere/releases/latest)
[![许可](https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF-MIT-green)](LICENSE)

[English](README.md) | 简体中文

</div>

RightHere 让 Finder 里的四件事变快：新建文件、在当前目录打开终端或编辑器、快速前往常用或隐藏路径、复制路径供别处使用。

适合经常在 Finder、终端和配置文件之间来回切换的人。

## 功能亮点

### 新建文件

在 Finder 右键菜单中直接新建常用文件，不用先打开对应 App 再另存为。

- 支持文本、Markdown、Word、Excel、PowerPoint 等常用文件类型
- 支持自定义模板，把自己的模板文件加入右键菜单
- 可选择显示哪些类型，保持右键菜单清爽
- 自动处理重名，例如 `新建文本文档 (2)`

### 在此处打开

以当前文件夹为工作目录打开终端或编辑器，省去复制路径和手动 `cd`。

- 支持终端，以及已安装的 iTerm、Warp、VS Code、Cursor
- 只显示本机实际装了的 App
- 支持右键文件夹、文件夹空白处和桌面空白处
- 不出现在文件右键菜单，避免和系统「打开方式」冲突

### 快捷前往

把常用文件、文件夹或隐藏路径加入 Finder 右键菜单，一键直达。

- 适合 `~/.zshrc`、`/etc/hosts`、`~/.codex` 这类隐藏配置路径
- 支持添加文件、添加文件夹或手动输入路径
- 每一项都可单独启用、隐藏、重命名或删除
- 由主 App 执行打开，避开 FinderSync extension 的沙盒限制

### 开发工具

复制所选项目的路径信息。

- 完整路径、文件名、不带扩展名文件名、所在文件夹、Markdown 链接
- 多选时每行输出一个结果
- 多个文件同属一个目录时，「所在文件夹」会自动去重

### 语言

界面跟随系统语言，也可以手动指定。

- 支持英文和简体中文
- 默认「跟随系统」
- 作用于设置窗口、Finder 右键菜单，以及新建文件的名称

### 轻量设置

所有能力都在一个小窗口里管理。

- 管理文件模板
- 逐个开关右键工具
- 控制哪些项目出现在 Finder 右键菜单中
- 菜单栏常驻，不打断当前工作流

## 安装

从 [GitHub Releases](https://github.com/LimeBits/RightHere/releases) 下载最新 DMG。

把 `RightHere.app` 拖到「应用程序」，然后打开一次。App 会注册并启用 Finder 扩展。如果右键菜单没有立刻出现，退出并重新打开 Finder，或重启 Finder 后再试。

系统要求：

- macOS 12.0 或更高版本
- Intel Mac 和 Apple Silicon Mac

## 使用

### 新建文件

在文件夹空白处或桌面空白处右键：

```text
新建文件 -> 文本文件 / Markdown / Word 文档 / ...
```

### 管理模板

打开 RightHere 设置，在「模板」页勾选要显示在右键菜单里的类型。

首次打开模板文件夹时，RightHere 会创建默认模板：

```text
template.txt
template.md
template.docx
template.xlsx
template.pptx
```

你可以直接编辑它们，也可以添加自己的 `template.<扩展名>` 文件：

```text
template.rtf
template.csv
template.json
template.swift
```

刷新设置页后新模板会出现在列表中，勾选后即显示在 Finder 里。

### 打开终端或编辑器

右键文件夹、文件夹空白处或桌面空白处：

```text
在此处打开 -> 终端 / Cursor / VS Code / ...
```

只列出本机已安装的 App。终端默认开启，第三方 App 需要在「工具」页主动勾选。

### 快捷前往

打开 RightHere 设置，在「工具」页添加文件、文件夹或路径。之后在 Finder 右键菜单中：

```text
快捷前往 -> 你的文件或文件夹
```

适合加入：

```text
~/.zshrc
/etc/hosts
~/.codex
~/Library/Application Support
```

### 复制路径

右键选中一个或多个项目：

```text
开发工具 -> 复制完整路径 / 复制文件名 / 复制 Markdown 链接 / ...
```

多选时每个项目占一行。

### 切换语言

打开 RightHere 设置，在「高级」页顶部的「语言」中选择「跟随系统」、「English」或「简体中文」。

切换语言也会改变之后新建文件的名称：英文下是 `New Text Document.txt`，中文下是 `新建文本文档.txt`。快捷前往中你自己改过的名称会保持原样。

## 更新与反馈

菜单栏选择 **帮助与反馈 -> 检查更新…** 可检查新版本。

选择 **帮助与反馈 -> 反馈问题…** 会打开预填诊断信息的 GitHub Issue 页面。**复制诊断信息** 会把同样的文本放进剪贴板，方便你自己粘贴。

RightHere 不收集 analytics，不会上传模板或文件内容。详见 [PRIVACY.zh-CN.md](PRIVACY.zh-CN.md)。

## 本地开发

克隆仓库后用 Xcode 打开 `RightHere.xcodeproj`。如果要长期本机调试，请把主 App 和 FinderSync extension 的 Team、Bundle ID、App Group 改成你自己的值。

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

仓库不提交个人 Team ID。由于 RightHere 使用 App Group 和 FinderSync extension，本机安装需要开发签名。可以通过环境变量传入自己的 Team ID：

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --force
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --universal --force
```

也可以在 Xcode 的 Signing & Capabilities 中为两个 target 选择自己的 Team。这会修改本地工程文件，提交前请确认没有把个人 Team ID 一起提交。

## FinderSync 测试与签名（硬性规定）

RightHere 的右键菜单依赖 `com.apple.FinderSync` 扩展；它和普通菜单栏 App 不同。**以下规则是强制流程，不是建议：**

1. **测试 Finder 右键前，主 App 与内嵌 `RightHereExtension.appex` 必须都是 Developer ID Application 签名，且 `TeamIdentifier` 为 `WV6JA6UHLN`。**
2. **禁止**把 ad-hoc、未签名或 Apple Development 签名的 DMG 拖入/复制到 `/Applications` 后用来测试 Finder 右键；它们可能被 `pluginkit` 显示为已登记，但 Finder 不会实际加载扩展。
3. `pluginkit -m` 中的 `+` **只表示扩展已登记/启用，不表示右键菜单可用**。每次测试包安装后，都必须在 Finder 的文件与文件夹空白处实际右键验证。
4. `Scripts/package-dmg.sh` 的常规模式会自动验证主 App 和扩展的 Developer ID 签名；签名不合格时必须失败，不能继续生成用于 FinderSync 测试的 DMG。
5. `--skip-signing` 只允许用于 CI 或编译检查，**绝不能**用于 FinderSync 实机测试、覆盖 `/Applications/RightHere.app`，或上传 GitHub Release / Sparkle 更新源。
6. 对外发布只能使用 `./Scripts/package-developer-id.sh` 产生、完成公证与 stapling 的包。上传前必须针对**指定的 DMG**运行发布预检，并显式传参生成 appcast：

```bash
./Scripts/release-preflight.sh \
  --tag vX.Y.Z \
  --dmg dist/RightHere-X.Y.Z-buildN-YYYYMMDD-HHMM.dmg \
  --notes RELEASE_NOTES.md

./Scripts/generate-appcast.sh \
  --dmg dist/RightHere-X.Y.Z-buildN-YYYYMMDD-HHMM.dmg \
  --tag vX.Y.Z \
  --notes RELEASE_NOTES.md
```

两个命令都会拒绝版本不一致、或混入历史版本的更新说明。

本机可测试的 Universal DMG：

```bash
RIGHTHERE_DMG_SKIP_FINDER_LAYOUT=1 ./Scripts/package-dmg.sh --universal
```

脚本成功时必须显示：

```text
✓ 已验证主 App 与 Finder Sync 扩展的 Developer ID 签名。
```

如需手动核验已安装 App：

```bash
codesign -dvvv /Applications/RightHere.app 2>&1 | \
  grep -E 'Authority=|TeamIdentifier='
codesign -dvvv /Applications/RightHere.app/Contents/PlugIns/RightHereExtension.appex 2>&1 | \
  grep -E 'Authority=|TeamIdentifier='
codesign --verify --deep --strict --verbose=2 /Applications/RightHere.app
```

应看到 `Authority=Developer ID Application: Bruce Tso (WV6JA6UHLN)` 和 `TeamIdentifier=WV6JA6UHLN`。出现 `Signature=adhoc`、`TeamIdentifier=not set` 或 `Apple Development` 时，停止测试并不要安装该包。

## 正式分发

给别人用的安装包必须是 Developer ID 签名、公证并 staple 过的 Universal DMG。GitHub Actions 产出的 DMG 只适合验证 CI 和打包流程，不适合在干净机器上验证 FinderSync。

打正式分发包：

```bash
RIGHTHERE_DEVELOPMENT_TEAM=YOURTEAMID \
./Scripts/package-developer-id.sh
```

首次使用前需要在 Xcode 里登录有效的 Apple Developer 账号，并准备 notarytool 凭据：

```bash
xcrun notarytool store-credentials "righthere-notary" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password"
```

RightHere 使用 Sparkle 2 作为 App 内更新框架。只能使用上面“显式指定 DMG”的命令生成 `appcast.xml`，并将该 DMG、它的校验文件和 `appcast.xml` 一起上传到同一个 GitHub Release。

## 常见问题

### Finder 右键菜单没有出现怎么办？

**普通用户**：确认从 GitHub Releases 下载、把 App 放入「应用程序」并至少打开过一次。若菜单没有立刻出现，退出并重新打开 Finder：

```bash
killall Finder
```

**开发/测试时**：先按上面的「FinderSync 测试与签名（硬性规定）」确认已安装 App 和内嵌扩展都是 Developer ID 签名。不要仅凭 `pluginkit` 的 `+` 判断成功；必须实际右键文件和文件夹空白处。如果安装的是 ad-hoc 或 Apple Development DMG，删除它并改用 `Scripts/package-dmg.sh --universal` 生成的已验签测试包。

### 为什么需要 FinderSync extension？

macOS 上要往 Finder 右键菜单加东西，必须通过 FinderSync extension。主 App 负责设置、模板和快捷前往请求，extension 负责把菜单渲染到 Finder 里。

### 为什么快捷前往由主 App 执行，而不是扩展？

FinderSync extension 运行在沙盒里，直接打开用户主目录、隐藏路径和部分系统路径不稳定。RightHere 会先把请求写入 App Group，再唤起主 App 执行。

### 切换语言会丢设置吗？

不会。模板的启用状态按扩展名存储，显示名是运行时计算的，切换语言不会改变勾选状态。快捷前往中你重命名过的项保留你的名字，只有四个内置默认项跟随语言。

## 目录结构

```text
RightHere/              主 App（SwiftUI 设置界面）
RightHereExtension/     FinderSync Extension
Scripts/                打包、安装和诊断脚本
deploy.sh               一键本机部署
monitor.sh              实时日志监控
DEVLOG.md               开发踩坑记录
```
