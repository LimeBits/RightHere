# RightHere

macOS Finder 右键「新建文件」扩展。在任意文件夹右键，即可快速新建 txt、md、docx、xlsx、pptx 文件。

## 功能

- 右键菜单新建文件，支持 txt / Markdown / Word / Excel / PowerPoint
- 主 App 可自由勾选在菜单中显示的文件类型
- 支持自定义模板：修改模板目录里的文件，新建时自动继承格式
- 文件名自动去重（新建文档、新建文档 (2)、…）

## 系统要求

- macOS 11.0 或更高版本
- Apple Silicon (arm64)

> 当前版本已在 macOS 15.0 上验证；macOS 11/12/13/14 仍需实机回归测试。

## 安装（本机开发版）

```bash
./deploy.sh --build
```

## 开发

```bash
# 编译 + 安装 + 激活扩展
./deploy.sh --build

# 实时查看扩展日志
./monitor.sh
```

## 分发计划

当前脚本主要服务本机开发部署。由于 RightHere 包含 FinderSync extension，不能依赖 ad-hoc 或 Apple Development 证书稳定分发给其他机器；正式分发需要 Apple Developer Program 提供的 Developer ID Application 证书和 Apple 公证。

后续应新增 `Scripts/package-release-dmg.sh`，用于完整生成可分发 DMG：

```text
1. Release build
2. 使用 Developer ID Application 证书签名主 App 和 RightHereExtension.appex
3. codesign --verify --deep --strict 验证签名
4. 创建 DMG
5. xcrun notarytool submit --wait 提交公证
6. xcrun stapler staple 绑定公证票据
7. spctl --assess 验证 Gatekeeper 可接受
```

在这个发布脚本完成前，推荐只使用 `deploy.sh --build` 做本机验证。

## 目录结构

```
RightHere/              主 App（SwiftUI 设置界面）
RightHereExtension/     FinderSync Extension
Scripts/                打包脚本
deploy.sh               一键本机部署
monitor.sh              实时日志监控
DEVLOG.md               开发踩坑记录
```
