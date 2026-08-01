# RightHere 开发踩坑记录

macOS Finder 右键"新建文件"扩展，基于 FinderSync Framework。

---

## 坑 1：Gatekeeper 拒绝安装

**现象**：双击 .app 报"无法打开，因为无法验证开发者"，或直接被系统静默拒绝。

**原因**：Apple Development 证书只能在注册过的设备上运行，Gatekeeper 会拦截未经公证的 app。

**解法**：
- 开发阶段：`xattr -cr /Applications/RightHere.app` 清除隔离标记，或在系统设置→隐私与安全中点击"仍要打开"。
- 分发给他人：必须用 Developer ID Application 证书签名并经过 Apple 公证（notarize），需要 $99/年的 Apple Developer 会员资格。

---

## 坑 2：App Group entitlements 缺失导致共享数据读不到

**现象**：主 App 保存的设置（启用的文件类型），Extension 读不到；Extension 写的心跳时间，主 App 读不到。

**原因**：两个 target（RightHere 主 App 和 RightHereExtension）都必须声明同一个 App Group，才能共享 UserDefaults suite。

**解法**：两个 target 的 entitlements 文件都加上：
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.LimeBits.RightHere</string>
</array>
```
同时在 Xcode Signing & Capabilities 里也要为两个 target 都添加 App Groups capability，并勾选同一个 group id。

Xcode build settings 中需要加：`CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION = YES`，否则 Xcode 会覆盖 entitlements 文件。

---

## 坑 3：FIFinderSyncController.directoryURLs 必须用真实路径

**现象**：Extension 注册了监听目录，但 Finder 右键菜单从不出现。

**原因**：沙盒环境下 `FileManager.default.homeDirectoryForCurrentUser` 返回的是沙盒容器路径（如 `/var/folders/...`），而不是真实的 `/Users/bruce`。`directoryURLs` 设置了假路径，Finder 匹配不到实际目录。

**解法**：用 `getpwuid(getuid())` 从系统密码数据库获取真实 home 路径：
```swift
if let pw = getpwuid(getuid()) {
    let realHome = String(cString: pw.pointee.pw_dir)
    let homeURL = URL(fileURLWithPath: realHome)
    // 用 homeURL 注册 directoryURLs
}
```

---

## 坑 4：NSMenuItem.representedObject 在 responder chain 中丢失

**现象**：菜单项点击后，`createNewFile(_ sender:)` 里 `sender.representedObject` 是 nil。

**原因**：FinderSync Extension 的菜单 action 通过 NSApp responder chain 分发，target=nil 时系统会把 action 发给 first responder，但 `representedObject` 不会被保留，到达 handler 时已经是 nil。

**解法**：改用 `NSMenuItem.tag` 存储索引，不依赖 representedObject：
```swift
for (index, type) in activeTypes.enumerated() {
    let item = NSMenuItem(title: type.displayName, action: #selector(createNewFile(_:)), keyEquivalent: "")
    item.tag = index  // 用 tag 而不是 representedObject
    submenu.addItem(item)
}

@objc func createNewFile(_ sender: NSMenuItem) {
    let type = activeTypes[sender.tag]  // 通过 tag 取回类型
}
```

---

## 坑 5：NSWorkspace.selectFile 触发权限弹窗

**现象**：文件创建成功后，系统弹出权限请求对话框，用户体验极差。

**原因**：`NSWorkspace.shared.selectFile(_:inFileViewerRootedAtPath:)` 会触发 Finder 打开并选中文件，在沙盒环境下需要额外的文件访问授权。

**解法**：直接删掉这行调用。文件创建后不需要主动在 Finder 中选中，用户自己能看到新文件。

---

## 坑 6：pluginkit CLI 是 macOS 15 上管理 FinderSync 的唯一可靠方式

**现象**：系统设置→扩展 里找不到 RightHere 扩展，无法手动启用。

**原因**：macOS 15 (Sequoia) 开始，开发证书签名的 FinderSync Extension 不再显示在系统设置 UI 中，只能用命令行管理。

**解法**：
```bash
# 启用扩展
pluginkit -e use -i com.LimeBits.RightHere.Extension

# 查看状态（+ 表示已启用）
pluginkit -m -p com.apple.FinderSync | grep RightHere

# 禁用扩展
pluginkit -e ignore -i com.LimeBits.RightHere.Extension
```

---

## 坑 7：Extension 沙盒阻止写入非标准目录

**现象**：在 Desktop 根目录（`~/Desktop`）可以新建文件，但在 `~/Desktop/b-vibe/` 等子目录右键，报"没有访问许可"。

**原因**：FinderSync Extension 运行在 App Sandbox 中，`user-selected.read-write` entitlement 只对通过 NSOpenPanel 用户主动选择的路径有效，不覆盖通过 FIFinderSyncController 获得的目标路径。

**解法**：关掉 Extension 的沙盒（仅限本地开发分发，App Store 上架不允许）：
```xml
<!-- RightHereExtension.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>
```
注意：主 App 的沙盒仍然保持开启，只关掉 Extension 的。

---

## 坑 8：Base64 模板数据损坏

**现象**：创建 .docx / .pptx 文件成功，但 Word/PowerPoint 打开报"文件损坏"或"格式无法识别"。

**原因**：嵌入在 Swift 源码里的 Base64 字符串在复制粘贴过程中被截断或出现填充错误，导致 Base64 解码失败或解码出非法 ZIP 数据（docx/xlsx/pptx 本质上是 ZIP 压缩包）。

**诊断方法**：
```python
import base64
data = base64.b64decode(your_base64_string)
print(data[:4].hex())  # 应该是 504b0304（ZIP magic bytes）
```

**解法**：用 Python 重新生成最小合法的 OOXML 文件并转成 Base64：
```python
import zipfile, io, base64
buf = io.BytesIO()
with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', '...')
    # ... 添加必要的 OOXML 结构文件
data = buf.getvalue()
print(base64.b64encode(data).decode())
```

---

## 坑 9：Xcode Debug build 产出 dylib 模式导致 deploy.sh 误判

**现象**：`deploy.sh` 用旧的 extension binary 做 hash 比对，有时判断"未重新编译"，实际上主 App 已经更新。或者复制后 `/Applications/RightHere.app/Contents/MacOS/` 是空目录，app 无法启动。

**原因**：Xcode 16+ 的 Debug build 会在 `MacOS/` 目录下生成 `RightHere.debug.dylib` 和 `__preview.dylib`（用于 Xcode Previews 热重载），主可执行文件是一个 launcher。`deploy.sh` 原来用 extension binary 做 hash 比对，不够准确。

**解法**：改用主 App 可执行文件（`Contents/MacOS/RightHere`）做 hash 比对，并在部署前检查该文件是否存在：
```bash
DERIVED_BIN="$DERIVED_APP/Contents/MacOS/RightHere"
if [ ! -f "$DERIVED_BIN" ]; then
    echo "✗ 主可执行文件不存在，build 可能失败"
    exit 1
fi
```

---

## 坑 10：FinderSync Extension 无法通过 ad-hoc 或 Apple Development 证书分发给他人

**现象**：打包成 DMG 发给朋友，安装后右键菜单不出现。pluginkit 完全找不到 extension（`pluginkit -m -p com.apple.FinderSync` 列表里没有 RightHere）。

**根本原因**：macOS 对 FinderSync Extension 的签名要求比普通 app 严格得多：

| 签名方式 | TeamIdentifier | pluginkit 能注册 | 适用场景 |
|---------|---------------|----------------|---------|
| ad-hoc（`--sign -`） | 无 | ✗ | 不适用 |
| Apple Development 证书 | 有，但绑定设备 UDID | 仅限 Xcode 直接 Run | 本机开发 |
| Developer ID Application 证书 | 有，公开可信 | ✓ | 分发给任何人 |

- **ad-hoc 签名**：`TeamIdentifier=not set`，系统直接拒绝注册 FinderSync extension，不会出现在 pluginkit 列表里，不会在「隐私与安全」里显示「允许」按钮。
- **Apple Development 证书打包**：有 Team ID，但 provisioning profile 绑定了开发者账号的设备 UDID。从 DerivedData 直接复制的 build 可以在本机用，重新签名后在别人机器上 pluginkit 仍然注册不进去。
- **`sudo xattr -cr` 也无法解决**：quarantine 标记不是问题所在，问题是证书本身不被系统信任用于加载系统级扩展。

**对比普通 app**：LocalFlow 等普通 app 用 ad-hoc 签名可以正常运行，因为它们不涉及系统扩展。FinderSync 是系统级组件，签名要求等同于内核扩展。

**结论**：
- **本机自用**：用 `deploy.sh` 从 DerivedData 直接复制，Apple Development 证书，完全正常。
- **分发给朋友**：必须购买 $99/年 Apple Developer Program，申请 Developer ID Application 证书，签名后用 `notarytool` 公证，才能让任何人安装使用。

**本机快速部署命令**：
```bash
./deploy.sh --build   # 编译 + 安装 + 激活扩展
```

## 坑 11：关闭 Extension 沙盒导致 pkd 拒绝注册

**现象**：`pluginkit -m -p com.apple.FinderSync` 列表里完全找不到 extension，`pluginkit -e use` 也没有效果，重启后依然如此。

**原因**：为了解决文件写入权限问题，把 extension 的 `com.apple.security.app-sandbox` 改成了 `false`。macOS 15 的 pkd 守护进程会拒绝注册没有沙盒的 FinderSync extension，导致 extension 从系统数据库彻底消失。

**解法**：恢复沙盒设置：
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```
重新编译部署后 extension 即可恢复注册。

**关于文件写入权限**：沙盒开着时，extension 只能写入 Desktop、Documents、Downloads 等标准目录，不能写入这些目录的子目录（如 `~/Desktop/b-vibe/`）。这是沙盒的正常限制，非标准目录无法通过 entitlements 解决，需要 Developer ID + 特定授权，或者接受这个限制。

---

## 坑 12：手动向 bundle 注入文件会破坏代码签名

**现象**：向已签名的 .app bundle 手动添加文件（如 AppIcon.icns）后，app 无法启动，报 `Launchd job spawn failed`。

**原因**：代码签名会对 bundle 内所有文件做 hash 校验，手动添加文件后签名失效，系统拒绝启动。

**解法**：不要手动向 bundle 注入文件再重签名——重签名会改变签名链，导致 extension 无法被 pkd 识别。正确做法是通过 Xcode 项目把资源文件编译进去。

**关于 icon**：Debug build 的 Assets.xcassets 没有被 Xcode 编译进 bundle，需要在 Xcode 里把 `Assets.xcassets` 加入项目（Add Files to Target）才能让图标在编译时自动打包进去。

---

## 坑 13：App Group UserDefaults 写操作触发循环权限弹窗

**现象**：在 Finder 里右键，还没点任何菜单项，就反复弹出系统权限请求窗口，无法操作。

**原因**：`menu(for:)` 里调用了 `updateHeartbeat()`，该函数通过 `SharedDefaults.sharedSuite`（即 `UserDefaults(suiteName: "group.com.LimeBits.RightHere")`）写入数据。在沙盒环境下，每次访问 App Group 容器都会触发 `tccd`（透明度、同意和控制守护进程）的权限检查，导致每次右键都弹出权限窗口。

**解法**：心跳数据改用 `UserDefaults.standard` 写入，不走 App Group 容器，彻底避免权限检查：
```swift
// extension 写
UserDefaults.standard.set(Date(), forKey: "extensionLastActive")

// 主 App 读
UserDefaults.standard.object(forKey: "extensionLastActive") as? Date
```

注意：`UserDefaults.standard` 在 extension 和主 App 之间不共享，但心跳只需要在 extension 本地记录、主 App 读取即可——两者运行在同一用户会话下，`standard` 的数据文件路径不同，实际上读不到对方的值。更准确的做法是主 App 通过 `pluginkit -m` 判断扩展状态，心跳仅作为辅助。

---

## 坑 14：deploy 后 extension 进程未启动导致右键菜单消失

**现象**：`deploy.sh` 跑完显示「✓ 部署成功」，pluginkit 状态是 `+`，但 Finder 右键没有菜单。

**原因**：`pluginkit -e use` 只是把 extension 标记为"允许使用"，并不会立即启动 extension 进程。系统需要一点时间懒加载启动进程。如果 deploy 后立刻重启 Finder，extension 进程还没起来，Finder 就找不到它。

**解法**：在 deploy.sh 里 `pluginkit -e use` 之后轮询等待 `RightHereExtension` 进程出现，再重启 Finder：
```bash
for i in 1 2 3 4 5; do
    pgrep -x RightHereExtension > /dev/null && break
    sleep 1
done
killall Finder
```

---

## 分发签名方式对比

| 场景 | 签名方式 | 成本 | 是否适合公开分发 |
|------|---------|------|------------|
| 当前（本机开发） | Apple Development | 免费 | ✗ 仅限自己设备 |
| 本地/网络分发 | Developer ID Application | $99/年 | ✓ 需公证（notarize） |
| App Store | Apple Distribution | $99/年 | ✓ 经 App Store 审核 |

获得 Developer ID 后的打包流程：
```bash
./Scripts/package-developer-id.sh  # archive/export + DMG + sign + notarize + staple
# 产物在 dist/RightHere-版本号-build号-时间戳.dmg
```

普通 `package-dmg.sh --skip-signing` 只适合 CI/打包流程验证，不适合新电脑安装验证 FinderSync。

---

## 坑 15：修改已安装 bundle 后 extension 菜单消失

**现象**：向 `/Applications/RightHere.app` 注入图标、重启 Dock 等操作后，Finder 右键菜单里「新建文件」消失。`pluginkit -m` 显示 extension 仍是 `+`，进程也在运行，但 `menu(for:)` 从不被调用。

**原因**：直接修改已安装 bundle 的内容会让 Finder 对 extension directoryURLs 的内部缓存失效，Finder 认为当前目录不在监听范围，菜单不出现。

**解法**：任何时候修改了 bundle 内容后，必须跑完整 deploy 流程：
```bash
./deploy.sh --build
```
不能只 `killall Finder`，必须走完 `pluginkit -e use` + 等待进程 + `killall Finder` 的完整流程。

**根本教训**：永远不要直接修改 `/Applications/RightHere.app` 里的文件，所有变更通过 `deploy.sh` 重新部署。

---

## 坑 16：首次打开设置页看不到旧模板文件夹里的自定义类型

**现象**：用户安装新版后，App Group 的 Templates 目录里已经存在 `template.rtf` 等旧模板，但首次打开设置页只显示内置 txt/md/docx/xlsx/pptx。必须点「刷新」或「打开模板文件夹」后，rtf 才出现在自定义模板列表。

**原因**：设置页为了避免首次打开触发 App Group 权限弹窗，只读取 `UserDefaults.standard` 里的本地模板缓存；如果缓存尚未建立，就回退到内置模板列表。旧模板文件虽然已经在共享模板目录里，但没有被同步进本地缓存。

**解法**：首次打开设置页时做一次静默扫描：
- 只读取已有模板目录并更新本地缓存；
- 不创建默认模板；
- 不写 App Group UserDefaults；
- 仅在本地缓存变化时通知 extension。

这样能发现旧模板目录里的 `template.rtf`，同时避免恢复到「打开设置页就重复权限弹窗」的状态。

---

## 坑 17：SwiftUI / AppKit 原生滚动条不适合 hover 即显示的轻量列表

**现象**：自定义模板列表的滚动条希望「鼠标进入列表区域即显示」，但使用 SwiftUI `ScrollView(showsIndicators:)` 或 AppKit overlay scroller 时，滚动条经常只在实际滚动时出现；而非 overlay scroller 又会显示较粗的轨道，视觉过重。

**原因**：macOS 原生 overlay scroller 的显示策略由系统控制，主要响应滚动手势，不适合做固定的 hover affordance。SwiftUI 的 `showsIndicators` 在 macOS 上动态切换也不总是可靠。

**解法**：隐藏系统 scroller，使用 `NSScrollView` 外加一条自绘的轻量 thumb：
- `NSTrackingArea` 监听鼠标进入/离开列表区域；
- `NSView.boundsDidChangeNotification` 监听滚动位置；
- 根据 `documentVisibleRect.origin.y / (documentHeight - visibleHeight)` 计算进度；
- thumb 使用浅色、窄宽度、圆角，并在 hover 时淡入淡出。

注意：AppKit 坐标系和直觉方向容易相反，顶部内容对应的 thumb 位置需要显式映射到顶部，滚到底时映射到底部。

---

## 坑 18：桌面右键时 Finder 不一定成为前台 App

**现象**：焦点位于其他 App 时，直接右键桌面背景，FinderSync 会收到桌面容器菜单请求，但 `NSWorkspace` 仍可能把原来的 App 报告为前台 App。全局要求 Finder 位于前台会让「新建文件」菜单消失。

**解法**：保留前台保护，但允许一个严格的桌面例外：菜单必须是容器背景类型，Finder 返回的目标目录必须明确等于真实的 `~/Desktop`。目标为空时不做桌面回退。菜单生成时固定模板和目标目录，点击时使用该上下文并再次验证目录。

FinderSync 也会出现在其他 App 的打开/保存窗口中。公开 API 无法完全区分浏览桌面的文件窗口与真实桌面背景，因此极少数文件窗口场景也可能看到该菜单，这是当前实现接受的边界。

诊断记录不能在每次右键时写 App Group，否则可能重新触发权限检查。扩展改用自己的 `UserDefaults.standard` 保存最多 100 条记录，通过分布式通知实时发送给主 App；主 App 启动时主动请求扩展缓冲快照，再保存到自己的本地诊断记录中。

---

## 坑 19：设置页模板开关和 Finder 右键菜单状态分叉

**现象**：在设置页取消勾选某个模板类型，例如 Word 文档，设置页显示已关闭，但 Finder 右键「新建文件」菜单里仍然能看到并创建该类型。

**原因**：主 App 设置页曾经优先使用本地 `UserDefaults.standard` 中的 `localDisabledFileTypes`，而 FinderSync extension 依赖 App Group 共享状态和分布式通知。UI 状态、共享禁用列表、模板文件夹缓存三者没有固定为同一个事实来源，导致设置页变化没有稳定传给扩展。

**最终模型**：
- 模板文件夹决定“有哪些模板”，文件名采用 `template.xxx`。
- App Group 里的 `disabledFileTypes` 决定“哪些模板显示在 Finder 右键菜单”。
- 设置页开关只负责显示/隐藏，不负责删除模板文件。
- 点击开关后写入 App Group 共享配置，并通知 FinderSync extension 重新加载。
- 设置页打开、刷新、App 回到前台时同步模板文件夹到共享缓存和本地缓存。
- Finder 右键菜单已经打开时不会中途刷新；下一次打开右键菜单必须使用新状态。

不采用“删除模板文件即隐藏”的原因：默认模板初始化会补齐缺失的内置模板，删除文件作为隐藏方式容易让用户困惑；保留开关并修复同步链路，用户心智更稳定。

布局上不再使用 macOS 默认 `TabView` 顶部标签，因为它会贴近标题栏。设置页改用内容区内的分段控件，保留顶部 Logo 和应用名称，下面再切换「模板 / 更新 / 高级」。

---

## 坑 20：Intel 首装后扩展已发现但未启用

**现象**：Intel Mac 上安装 Universal DMG 后，`file` 显示主 App 和 FinderSync extension 都包含 `x86_64`，`pluginkit -m -p com.apple.FinderSync -A -D -v` 也能看到 `com.LimeBits.RightHere.Extension`，但行首没有 `+`，Finder 右键菜单不出现。手动执行下面命令后菜单立即恢复：

```bash
pluginkit -e use -i com.LimeBits.RightHere.Extension
killall Finder
```

**原因**：不是架构适配问题，而是首次安装时 LaunchServices / PKD 对新 extension 的登记存在延迟。App 或安装脚本太早执行 `pluginkit -e use` 时，系统还没稳定发现扩展，后续列表里虽然出现了 extension，但没有进入 `+` 启用状态。

**解法**：安装脚本和 App 启动侧都要先注册 App，再轮询等待 FinderSync extension 出现在 `pluginkit -m -p com.apple.FinderSync -A -D` 列表里，然后执行 `pluginkit -e use`，再确认行首变成 `+`。只有从未启用变为已启用时才重启 Finder，避免每次启动都打断用户当前 Finder 会话。

正式分发包还需要注意：拖拽安装后用户只会打开 App，不会运行安装脚本。主 App 如果保持 App Sandbox，内部执行 `pluginkit` / `killall Finder` 这类系统工具可能被沙盒限制，导致只有安装脚本路径能成功。RightHere 公开分发不走 App Store，因此主 App 取消 App Sandbox，保留 Developer ID 签名、hardened runtime、公证和 App Group；FinderSync extension 仍保持沙盒和最小文件权限。

---

## 快速调试流程

```bash
# 本机部署（日常使用）
./deploy.sh --build

# 实时查看 Extension 日志
./monitor.sh

# 查看 Extension 状态
pluginkit -m -p com.apple.FinderSync | grep RightHere

# 手动重启 Finder
killall Finder
```
