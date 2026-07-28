# RightHere 0.1.6

发布时间：2026-07-28

## 主要变化

- 修复其他 App 位于前台时，在真实桌面背景右键无法稳定显示「新建文件」菜单的问题。
- 菜单生成时固定模板和目标目录，避免点击子菜单时焦点变化导致文件创建到错误位置。
- FinderSync extension 自动保留最近 100 条本地诊断记录，主 App 启动后自动同步。
- 「复制诊断信息」和反馈 Issue 自动附带最近的扩展菜单与文件创建诊断记录。
- 本地打包脚本支持读取本机 `Scripts/dev-identity.sh` 中的 Team ID，便于开发机快速生成 FinderSync 验证包。

## 已验证

- 脚本语法检查：`bash -n Scripts/package-app.sh Scripts/package-dmg.sh`
- 文档/补丁空白检查：`git diff --check`
- Release Universal build：`arm64 + x86_64`
- 已生成 Universal DMG 并在本机验证桌面背景右键菜单

## GitHub Release 安装包

- 上传附件：`dist/RightHere-0.1.6-20260728-2341.dmg`
- 文件大小：2.3 MB
- 镜像格式：UDZO，只读压缩 DMG
- SHA-256：`4709ad475c31ac531a99d71d4a26c641ca41f1346dbe4f6de545ace63685b9ab`

建议创建 tag `v0.1.6` 后，在 GitHub Release 中上传 DMG 作为 release asset。`dist/` 已被 `.gitignore` 排除，不建议把 DMG 直接提交到 Git 仓库。

## 发布说明

RightHere 是一个 macOS Finder 右键「新建文件」扩展。安装后可以在 Finder 中快速创建 txt、Markdown、Word、Excel、PowerPoint 或自定义模板文件。

安装方式：

1. 下载 `RightHere-0.1.6-20260728-2341.dmg`。
2. 打开 DMG。
3. 将 `RightHere.app` 拖到 `Applications`。
4. 启动 RightHere，并在系统设置的 Finder 扩展中启用 RightHere。
5. 如果 Finder 右键菜单没有立即出现，重启 Finder 或注销后重新登录。

注意：当前分发包仍主要面向开发机或受信任设备验证。公开分发给普通用户前，仍建议补齐 Developer ID 签名、公证和 stapler 绑定公证票据。
