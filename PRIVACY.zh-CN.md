<div align="center">

# 隐私政策

[English](PRIVACY.md) | 简体中文

</div>

RightHere 是一个本地运行的 macOS Finder 扩展。核心功能都在你的 Mac 上完成，不需要账号，也没有自建后端服务。

## RightHere 访问哪些内容

- 使用 FinderSync 在 Finder 右键菜单中添加菜单项。
- 从 RightHere 本地模板目录读取模板文件，让新建的文件继承你选择的模板内容。
- 本地设置保存在 macOS UserDefaults 中。
- 主 App 和扩展通过配置的 App Group 容器共享模板元数据。
- 扩展在本地保留最多 100 条诊断记录的滚动缓冲。这些记录可能包含本地目标路径、菜单上下文和文件创建结果，但绝不包含文件内容。

RightHere 不会上传你的模板、文件、文件夹名称或 Finder 中的选择。

## 网络访问

只有当你从菜单栏选择 **帮助与反馈 -> 检查更新…** 时，RightHere 才会连接 GitHub。

该请求读取 GitHub Releases 的元数据，仅用于告知你是否有新版本。

RightHere 也使用 Sparkle 2 进行 App 内更新。自动检查可以在设置的「更新」页关闭。更新只在你确认后才会下载和安装。

RightHere 不收集 analytics，不会自动发送诊断信息。诊断记录只在扩展和菜单栏 App 之间本地同步。

## 反馈

反馈菜单会在浏览器中打开一个 GitHub Issue 页面，并预填诊断信息。提交前你可以查看和修改这些文本。

诊断文本包含 App 版本、macOS 版本、CPU 架构、界面语言、模板数量、已启用的文件扩展名、扩展响应时间、最近的扩展事件和相关本地路径。不包含模板文件内容，也不包含用户文件内容。
