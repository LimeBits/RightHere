# Changelog

## [0.1.2] - 2026-06-04

### 修复
- **右键菜单消失**：修改 bundle 内容（注入图标、重启 Dock）后导致 Finder extension 缓存失效，需通过完整 deploy 流程恢复

### 优化
- App icon 重新设计：去掉折角，改为干净圆角矩形文件 + 蓝色加号徽章，更简洁现代

### 文档
- DEVLOG 补充坑 13（App Group 权限弹窗）、坑 14（extension 进程未启动）、坑 15（bundle 修改导致菜单消失）

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
