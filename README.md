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

## 目录结构

```
RightHere/              主 App（SwiftUI 设置界面）
RightHereExtension/     FinderSync Extension
Scripts/                打包脚本
deploy.sh               一键本机部署
monitor.sh              实时日志监控
DEVLOG.md               开发踩坑记录
```
