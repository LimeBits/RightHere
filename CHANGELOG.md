# Changelog

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
