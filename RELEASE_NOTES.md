# RightHere 0.1.3

发布时间：2026-06-06

## 主要变化

- 设置页自定义模板区域重新整理为紧凑列表，复选框左对齐，图标与文件类型名称对齐。
- 自定义模板列表会在首次打开设置页时扫描已有模板目录，自动显示旧模板文件夹里的 `template.rtf` 等类型。
- 模板列表滚动条改为轻量自定义浮层，鼠标悬停即显示，颜色更浅，滚动方向符合常规阅读习惯。
- 减少 Finder 右键菜单阶段的 App Group 访问，降低重复权限弹窗出现的概率。
- 调整设置窗口高度和底部状态栏留白，让版本号与 Finder 响应状态不再贴底。

## 已验证

- Debug build：`xcodebuild -project RightHere.xcodeproj -scheme RightHere -configuration Debug build`
- 本机部署：`./deploy.sh --build --force`
- FinderSync extension 状态：`+ com.b-vibe.RightHere.Extension(0.1.3)`

## 分发包

- DMG：`dist/RightHere-0.1.3-*.dmg`

注意：当前分发包仍使用 Apple Development 证书，主要用于本机/开发设备验证。公开分发仍需要 Developer ID 签名与公证。
