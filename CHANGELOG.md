# Changelog

## [0.1.5] - 2026-06-19

### 新增
- 菜单栏新增「帮助与反馈」，支持检查 GitHub Releases 更新、打开项目主页、打开 Issues、复制诊断信息和创建反馈 Issue。
- 新增 `LICENSE`、`PRIVACY.md`、`RELEASE_CHECKLIST.md`、GitHub Issue 模板和 `Scripts/doctor.sh`，完善开源协作准备。
- 设置页新增 Finder 最近响应状态、模板空状态和全部模板禁用提示。

### 优化
- 开源仓库移除个人 Team ID，改为通过 `DEVELOPMENT_TEAM` 环境变量进行本地开发签名。
- `deploy.sh` 和打包脚本支持本机架构与 Universal Binary 构建。
- DMG 改为标准拖拽安装布局：`RightHere.app` 拖到 `Applications`，内部安装脚本改为可选参数。
- App icon 增加透明安全边距，改善 Launchpad 中的视觉尺寸。
- README 补充本地开发、签名、隐私、打包和公开分发状态说明。

### 修复
- 修复主 App 无法可靠读取 FinderSync extension 最近活跃时间的问题。
- 手动检查更新时，如果 GitHub Releases 尚未创建，显示更明确的提示。

### 测试
- 已通过脚本语法检查和 `git diff --check`。
- 已通过 `xcodebuild` 双架构 Debug 构建：`arm64 + x86_64`。
- 已生成 Universal DMG 用于内部验证。

---

## [0.1.4] - 2026-06-06

### 优化
- 更新 macOS App icon 为蓝色圆角底板 + 白色文件加号图标，匹配当前应用视觉。
- 重新生成 `16/32/64/128/256/512/1024` 全套 AppIcon PNG 资源。

### 修复
- 修复由截图源图外侧白色背景/高光残留导致的 App icon 白边问题，深色背景下显示更干净。

### 测试
- 已通过 `xcodebuild -project RightHere.xcodeproj -scheme RightHere -configuration Debug -arch arm64 build`。
- 已通过 `./deploy.sh --build --force` 在本机部署，FinderSync extension 状态为启用。

---

## [0.1.3] - 2026-06-06

### 新增
- 自定义模板列表支持安装后首次打开设置页时静默扫描已有模板目录，自动发现 `template.rtf` 等历史自定义模板。
- 设置页模板列表加入自定义轻量滚动条：鼠标悬停区域即显示，颜色更浅，滚动进度与列表位置一致。

### 优化
- 设置页改为更紧凑的自定义模板管理界面，复选框统一左对齐，模板图标与名称列对齐。
- 删除模板行下方的 `template.xxx` 副标题，仅保留文件类型名称。
- 设置窗口增高，底部状态栏加高，避免版本号与 Finder 响应状态贴近窗口底部。
- Finder extension 菜单构建阶段减少 App Group 读写，避免右键或首次打开设置页时重复触发系统权限弹窗。

### 修复
- 修复 SwiftUI `ScrollView(showsIndicators:)` 在 macOS 上 hover 切换滚动条不可靠的问题。
- 修复自定义滚动条进度方向反向的问题。
- 修复自定义模板（如 rtf）需要手动刷新/打开模板文件夹后才出现在设置页的问题。

### 测试
- 已通过 `xcodebuild -project RightHere.xcodeproj -scheme RightHere -configuration Debug build`。
- 已通过 `./deploy.sh --build --force` 在本机部署，FinderSync extension 状态为启用。

---

## [0.1.2] - 2026-06-04

### 修复
- **右键菜单消失**：修改 bundle 内容（注入图标、重启 Dock）后导致 Finder extension 缓存失效，需通过完整 deploy 流程恢复
- **桌面无法新建文件**：为 FinderSync extension 增加 Desktop home-relative 读写例外，保持沙盒开启的同时允许在桌面创建文件
- **App icon 缺失**：将 `Assets.xcassets` 加入 Xcode Resources build phase，避免手动向 bundle 注入图标导致签名/扩展缓存问题
- **DMG 安装后右键菜单可能消失**：安装脚本在启用扩展后等待 `RightHereExtension` 进程启动，再重启 Finder

### 优化
- App icon 重新设计：去掉折角，改为干净圆角矩形文件 + 蓝色加号徽章，更简洁现代
- 主 App 改为菜单栏常驻，隐藏 Dock 图标；macOS 11-14 保留「打开扩展设置」入口，macOS 15+ 隐藏该入口
- 打包脚本改为从编译后的 App 读取版本号，并移除手动生成/注入 `AppIcon.icns` 的逻辑

### 文档
- DEVLOG 补充坑 13（App Group 权限弹窗）、坑 14（extension 进程未启动）、坑 15（bundle 修改导致菜单消失）
- README 系统要求曾恢复为 macOS 11.0 或更高版本；后续开源目标已统一为 macOS 12.0+。

### 测试
- 已在 macOS 15.0 上验证菜单栏常驻、Downloads 与 Desktop 新建文件、Finder 右键菜单可用
- macOS 11/12/13/14 尚未实机回归测试

---

## [0.1.1] - 2026-06-03

### 修复
- **右键弹出循环权限窗口**：extension 心跳从 App Group UserDefaults 改为 UserDefaults.standard，避免每次右键触发 tccd 权限检查
- **deploy 后右键菜单消失**：deploy.sh 新增等待 RightHereExtension 进程启动的轮询，确保进程就绪后再重启 Finder
- **extension 版本号不一致警告**：Info.plist 改用 `$(MARKETING_VERSION)` 变量，与主 App 版本号保持同步

### 新增
- 支持 Universal Binary（arm64 + x86_64），兼容 Intel Mac
- deployment target 调整为 macOS 12.0，支持 Monterey 及以上
- `deploy.sh --build --universal` 编译双架构版本
- git 分支管理：main（稳定）/ dev（开发）
- CHANGELOG.md、README.md

---

## [0.1.0] - 2026-06-03

首个稳定版本。

### 功能
- Finder 右键菜单「新建文件」，支持 txt / md / docx / xlsx / pptx
- 主 App 设置界面：勾选/取消各文件类型的菜单显示
- 自定义模板支持：打开模板文件夹，修改模板后新建文件自动继承
- 文件名自动编号，避免重名冲突
- 扩展心跳检测，主 App 实时显示扩展启用状态

### 技术
- FinderSync Extension + App Group 共享数据
- 使用 `getpwuid` 获取真实 home 路径，解决沙盒路径问题
- 使用 `NSMenuItem.tag` 传递类型索引，绕过 responder chain 丢失 representedObject 问题
- 内嵌最小合法 OOXML 模板（docx / xlsx / pptx）
- `deploy.sh` 一键编译部署，`monitor.sh` 实时日志


首个稳定版本。

### 功能
- Finder 右键菜单「新建文件」，支持 txt / md / docx / xlsx / pptx
- 主 App 设置界面：勾选/取消各文件类型的菜单显示
- 自定义模板支持：打开模板文件夹，修改模板后新建文件自动继承
- 文件名自动编号，避免重名冲突
- 扩展心跳检测，主 App 实时显示扩展启用状态

### 技术
- FinderSync Extension + App Group 共享数据
- 使用 `getpwuid` 获取真实 home 路径，解决沙盒路径问题
- 使用 `NSMenuItem.tag` 传递类型索引，绕过 responder chain 丢失 representedObject 问题
- 内嵌最小合法 OOXML 模板（docx / xlsx / pptx）
- `deploy.sh` 一键编译部署，`monitor.sh` 实时日志
