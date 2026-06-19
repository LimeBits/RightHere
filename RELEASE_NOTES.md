# RightHere 0.1.5

发布时间：2026-06-19

## 主要变化

- 菜单栏新增「帮助与反馈」，支持检查 GitHub Releases 更新、打开项目主页、打开 Issues、复制诊断信息和创建反馈 Issue。
- 新增 `LICENSE`、`PRIVACY.md`、`RELEASE_CHECKLIST.md`、GitHub Issue 模板和 `Scripts/doctor.sh`，完善开源协作准备。
- 设置页新增 Finder 最近响应状态、模板空状态和全部模板禁用提示。
- 开源仓库移除个人 Team ID，改为通过 `DEVELOPMENT_TEAM` 环境变量进行本地开发签名。
- `deploy.sh` 和打包脚本支持本机架构与 Universal Binary 构建。
- DMG 改为标准拖拽安装布局：将 `RightHere.app` 拖到 `Applications`。

## 已验证

- 脚本语法检查：`bash -n deploy.sh Scripts/package-app.sh Scripts/package-dmg.sh Scripts/install.sh Scripts/doctor.sh Scripts/check-installed-version.sh monitor.sh`
- 文档/补丁空白检查：`git diff --check`
- Debug build：`xcodebuild` 双架构构建，`arm64 + x86_64`
- 已生成 Universal DMG 用于内部验证

## GitHub Release 安装包

- 上传附件：`dist/RightHere-0.1.5-20260619-2237.dmg`
- 文件大小：2.3 MB
- 镜像格式：UDZO，只读压缩 DMG
- SHA-256：`fa6e9774f143d0f9d49b52419e2916ae7824e1279061c2c40c42332fecbb432a`

建议创建 tag `v0.1.5` 后，在 GitHub Release 中上传上面的 DMG 作为 release asset。`dist/` 已被 `.gitignore` 排除，不建议把 DMG 直接提交到 Git 仓库。

## 发布说明

RightHere 是一个 macOS Finder 右键「新建文件」扩展。安装后可以在 Finder 中快速创建 txt、Markdown、Word、Excel、PowerPoint 或自定义模板文件。

安装方式：

1. 下载 `RightHere-0.1.5-20260619-2237.dmg`。
2. 打开 DMG。
3. 将 `RightHere.app` 拖到 `Applications`。
4. 启动 RightHere，并在系统设置的 Finder 扩展中启用 RightHere。
5. 如果 Finder 右键菜单没有立即出现，重启 Finder 或注销后重新登录。

注意：当前分发包仍主要面向开发机或受信任设备验证。公开分发给普通用户前，仍建议补齐 Developer ID 签名、公证和 stapler 绑定公证票据。
