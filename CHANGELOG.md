# Changelog

## [0.4.4] - 2026-08-16

### 新增
- 「高级」页在“语言”和“右键菜单”之间新增“开机自启动”开关。首次设置默认开启；用户关闭后会尊重该选择。macOS 13 及以上使用系统 `SMAppService`，macOS 11/12 使用当前用户的 LaunchAgent，无需管理员权限。
- 首次安装、重新安装或更新到新构建后的首次运行自动展示设置页，为菜单栏应用提供安装/更新成功的明确反馈；从启动台启动也会触发，同一安装实例的后续正常启动不会重复弹出。

### 调整
- 移除将 Finder Sync 误称为系统扩展的设置入口和相关跳转；异常状态现在可直接“重新尝试”登记与启用 Finder Sync。
- 精简菜单栏“帮助与反馈”：移除重复的 GitHub Issues 和未使用的扩展设置入口，保留检查更新、反馈问题、复制诊断信息和项目主页。

### 打包与验证
- 本地 FinderSync 测试 DMG 强制校验主 App 与内嵌扩展均为 Developer ID 签名；签名不合格时中止打包，避免 ad-hoc 包导致 Finder 不加载右键扩展。
- 明确 `pluginkit` 的启用状态不能替代实际 Finder 右键验证；发布清单、开发文档和中英文 README 均新增硬性测试规则。
- 已在 Apple Silicon 和 Intel Mac 上验证 Universal Developer ID 测试包的 Finder 右键菜单可用。

---

## [0.4.3] - 2026-08-15

### 新增
- 「快捷前往」支持拖动排序，顺序会保存到 App Group，并同步到 Finder 右键菜单。
- 拖动时显示当前项目和目标位置，减少排序过程中的跳动和误操作。

### 调整
- 优化「快捷前往」列表布局，压缩拖动手柄、复选框和文件夹图标之间的间距。
- 重命名按钮改为圆角工具按钮，并保留打开、在 Finder 中显示和删除操作。
- 模板页增加与工具页一致的整体圆角背景。
- 补充拖动排序相关的中文本地化文案，并保持 macOS 11 兼容。

---
## [0.4.2] - 2026-08-14

### 修复
- 修复上一版本使用开发签名发布，导致其他 Mac 无法启动的问题。正式安装包现使用 Developer ID 签名、Apple 公证和 stapling，可在 Intel 与 Apple 芯片 Mac 上正常安装。

### 兼容性
- 最低系统版本调整为 macOS 11。
- Finder 扩展在 macOS 11 上使用单色 SF Symbol 回退方案，避免调用仅在 macOS 12 可用的调色板图标 API。

---
## [0.4.1] - 2026-08-12

### 新增
- 右键菜单的每一个选项前面现在都会显示图标，新建文件的子选项会根据文件类型显示对应的彩色图标（文本、Markdown、Word、Excel、PPT 等），「在此处打开」的子选项会显示对应 App 的真实图标，让菜单一眼就能看清楚每个操作是什么。
- 在设置页「高级」标签下新增「菜单图标」开关，可以随时关闭菜单图标，让右键菜单回到纯文字样式。
- 「在此处打开」新增支持 Zed 和 ChatGPT（原 Codex），与已有的终端、iTerm、Warp、VS Code、Cursor 并列显示，只有本机已安装的 App 才会出现。

---

## [0.4.0] - 2026-08-05

### 新增
- 支持英文界面。界面语言跟随系统语言，中文系统显示中文，其他语言显示英文，无需在 App 内切换。
- 右键新建的文档名称会跟随语言：英文环境下创建 `New Text Document.txt`、`New Excel Worksheet.xlsx`，中文环境保持原有的「新建文本文档.txt」。重名仍然追加 `(2)`。
- 右键菜单文案对齐 macOS 术语：`New File` / `Open Here` / `Go To` / `Dev Tools`。
- 「快捷前往」的内置默认项在英文环境下显示为 `Home` / `Downloads` / `Documents` / `Desktop`。

### 说明
- 升级不会影响已有设置。模板的启用状态按扩展名存储，显示名是运行时计算的，因此切换语言不会让勾选状态丢失。
- 已经自定义过的「快捷前往」名称会原样保留，只有全新安装才会使用本地化的默认名称。
- 主 App 和 Finder 扩展共用同一份 `Localizable.xcstrings`，两个 bundle 的文案不会出现分叉。

---

## [0.3.1] - 2026-08-04

### 修复
- 修复 Debug 构建启动时偶发弹出「无法检查更新 / 无法启动更新程序」的问题。Debug 构建的 `SUPublicEDKey` 为空且强制验签，任何计划检查都必然失败，现在直接停用自动检查；手动检查不受影响。
- 设置页「版本更新」开关在 Debug 构建中置灰并说明原因，避免开关状态和实际行为不一致。正式构建行为不变。

### 调整
- Finder 右键菜单「快捷打开」改名为「快捷前往」，更准确描述导航语义，也和 macOS Finder「前往」的措辞一致。设置页相关文案同步更新。
- 设置页标签顺序调整为「模板 / 工具 / 高级 / 更新」，更新放最后。

---

## [0.3.0] - 2026-08-03

### 新增
- Batch 2 完成：Finder 右键菜单新增“开发工具”子菜单，包含复制完整路径、复制文件名、复制不带扩展名文件名、复制所在文件夹路径和复制 Markdown 链接。
- 多选时每行输出一个结果；“复制所在文件夹路径”在多选同目录时自动去重。
- Markdown 链接使用 `[文件名](file://...)` 格式，路径中的空格、`#`、`?`、`(`、`)` 会做 percent-encoding，可直接在 Obsidian、Bear 等编辑器中点击打开。
- 右键文件夹或文件夹空白处时隐藏“复制所在文件夹路径”和“复制不带扩展名文件名”，避免和“复制完整路径”“复制文件名”输出重复。
- 设置页“工具”标签新增“开发工具”总开关，默认开启；五个菜单项不再单独配置，避免设置项过碎。
- “在此处打开”从只支持终端扩展为支持 iTerm、Warp、VS Code 和 Cursor，通过 `NSWorkspace` 按 bundle identifier 检测，只有本机已安装的 App 才会出现在设置页和右键菜单中。
- 设置页“在此处打开”卡片列出已安装的 App 并可逐个开关；终端默认开启，第三方 App 默认关闭，需要用户主动勾选。
- App 开关状态按 App 记录，卸载后重新安装不会丢失之前的选择；设置页重新获得焦点时会重新检测已安装的 App。

### 说明
- 开发工具只写系统剪贴板，不读写文件，也不写 App Group 容器，因此不会触发额外的沙盒权限检查。
- “在此处打开”仍然只在右键文件夹、文件夹空白处和桌面空白处显示，右键单个文件或多选时不显示，避免和 Finder 原生“打开方式”冲突。

---

## [0.2.0] - 2026-08-01

### 新增
- Batch 1 右键增强：新增“右键工具”设置页。
- Finder 右键菜单新增“在此处打开 -> 终端”，仅在文件夹、文件夹空白处和桌面空白处显示，避免和文件右键“打开方式”冲突。
- 新增“快捷打开”，支持添加文件、文件夹和手动输入隐藏路径，例如 `~/.zshrc`、`/etc/hosts`、`~/.codex`。
- 快捷打开支持开关、重命名、删除、打开和在 Finder 中显示；设置会通过 App Group 同步给 FinderSync extension。
- 快捷打开改由主 App 打开，避免 FinderSync extension 因沙盒限制无法打开用户主目录或隐藏路径。
- 快捷打开请求会先写入 App Group，并通过 `righthere://open-shortcut` 唤起主 App，即使主 App 尚未运行也能完成打开。

### 修复
- 去掉 Finder 右键菜单中“新建文件”“在此处打开”“快捷打开”之间的手动分隔线，避免部分系统显示为空白菜单项。
- 调整“工具”设置页布局，将快捷打开做成独立管理区，并将“添加文件或文件夹/输入路径”移到底部。
- 将快捷打开的强失效样式改为“未验证”弱提示，避免隐藏路径被误判时造成误解。
- 修复“快捷打开”菜单点击后没有打开文件夹的问题：诊断显示 extension 已写入 pending request，但主 App 没有可靠消费；现在主 App 会在 URL 事件、启动和重新激活时都检查并执行 pending request。

---

## [0.1.14] - 2026-08-01

### 修复
- 修复普通用户拖拽 RightHere.app 到 `/Applications` 后，首次打开 App 仍无法自动启用 Finder 右键菜单的问题。
- 主 App 正式分发版取消 App Sandbox，保留 Developer ID、hardened runtime、公证和 App Group，使首次启动时可以自行注册并启用 FinderSync extension。
- 启动时会等待 FinderSync extension 被系统登记后再执行启用，并确认 `pluginkit` 进入 `+` 状态；从未启用变为已启用时自动重启 Finder。

### 验证
- 已在 Intel Mac 上验证：不运行安装脚本、不手动执行 `pluginkit`，仅拖拽安装并打开 App 后，Finder 右键「新建文件」菜单可正常出现。

---

## [0.1.13] - 2026-08-01

### 修复
- 修复设置页取消勾选模板后，Finder 右键菜单仍显示该模板的问题。
- FinderSync extension 启动时改为读取共享模板缓存和共享启用状态，避免首次右键菜单使用旧的默认模板列表。
- 安装和启动时会等待 FinderSync extension 被系统登记后再启用，并验证 `pluginkit` 已进入 `+` 状态；修复部分 Intel Mac 首装后扩展已发现但右键菜单不出现的问题。
- 设置页回到前台或点击刷新时，会同步模板文件夹、设置页列表和 Finder 右键菜单。

### 优化
- 设置页顶部标签改为内容区内的分段控件，避免默认 TabView 贴近标题栏。
- 「模板 / 更新 / 高级」继续分区展示，但保留顶部 RightHere 品牌区，整体层级更清楚。
- 诊断信息中的启用模板改为读取 Finder extension 同源共享状态，减少排查误导。

### 设计结论
- 模板文件夹决定“有哪些模板”，设置页开关决定“哪些模板显示在 Finder 右键菜单”。
- 删除模板文件不作为主要隐藏方式，因为默认模板初始化可能会补回缺失的内置模板。
- 已经打开的 Finder 右键菜单不会中途刷新；设置变更会在下一次打开右键菜单时生效。

---

## [0.1.12] - 2026-08-01

### 修复
- 补齐 sandboxed App 使用 Sparkle installer 所需的 mach lookup entitlement，修复发现更新后安装失败的问题。
- Sparkle feed 改为强制 signed appcast，并在更新前校验包签名和下载内容。

### 优化
- appcast 生成时嵌入 Markdown 更新说明，让默认更新窗口展示更完整的版本内容。

---

## [0.1.11] - 2026-08-01

### 优化
- 将「打开扩展设置」移入「帮助与反馈」子菜单，减少正常使用时的菜单噪音。
- App 和 FinderSync extension 声明中文本地化，改善 Sparkle 更新窗口在中文系统下显示英文的问题。
- 设置页新增「停用 Finder 扩展」入口，用于卸载前清理右键菜单残留。

### 修复
- 增大设置窗口默认高度，并调整底部状态栏布局，避免「最近 Finder 调用」文字被遮挡。

---

## [0.1.10] - 2026-08-01

### 优化
- 默认开启 Sparkle 自动检查更新，避免首次启动弹出英文授权提示，降低新用户安装后的打扰。
- 设置页新增「版本更新」开关，用户可随时关闭或重新开启自动检查更新。
- 保留菜单栏「检查更新...」手动入口，不默认启用后台自动下载和安装更新。

---

## [0.1.9] - 2026-07-31

### 修复
- 将 Sparkle 更新配置写入主 App 的显式 `Info.plist`，确保正式包包含 `SUFeedURL`、`SUPublicEDKey` 和 installer launcher 设置。
- `Scripts/generate-appcast.sh` 生成 appcast 时加入 GitHub Release 下载 URL 前缀，避免 Sparkle 拿到相对路径下载地址。
- appcast 生成后强制校验 `sparkle:edSignature` 和 HTTPS 下载地址，避免再次发布无法被 Sparkle 验证的更新源。

### 分发
- 0.1.8 已发布包的更新配置不完整，0.1.9 作为修复版重新走 Developer ID 签名、公证和 stapler 流程。

---

## [0.1.8] - 2026-07-31

### 修复
- RightHere 启动时自动注册当前 App 并启用 FinderSync extension，改善普通用户拖拽安装后右键菜单不出现的问题。
- 为 FinderSync extension 增加 Documents 写入权限，修复「文稿」文件夹有菜单但新建文件无反应的问题。
- 安装脚本刷新 LaunchServices 与 Dock 图标缓存，改善 Launchpad 首次安装后图标短暂透明的问题。

### 新增
- 接入 Sparkle 2 更新框架，App 内「检查更新」可用于后续正式版本的一键下载、签名验证和安装。
- 新增 `Scripts/generate-appcast.sh`，用于为正式 DMG 生成 Sparkle `appcast.xml`。

### 分发
- 继续要求公开安装包必须为 Developer ID Application 签名、公证并 staple 的 Universal DMG。
- 正式打包现在要求提供 `SPARKLE_PUBLIC_ED_KEY`，避免发布不能自动更新的包。

---

## [0.1.7] - 2026-07-30

### 新增
- 新增 Developer ID 正式分发脚本：归档、Developer ID 导出、DMG 打包、DMG 签名、公证和 stapler 绑定走同一条命令。
- 正式分发脚本强制校验 Universal Binary，确保主 App 和 FinderSync extension 同时包含 `arm64` 与 `x86_64`。
- 安装脚本会清理旧 bundle id 的 FinderSync 状态，并启用新的 `com.LimeBits.RightHere.Extension` 后重启 Finder。

### 优化
- 主 App 和 FinderSync extension 切换到 `com.LimeBits.RightHere` / `com.LimeBits.RightHere.Extension`，App Group 切换到 `group.com.LimeBits.RightHere`。
- 设置页不再把系统扩展列表读取失败当作用户必须处理的错误；只有明确未启用或未注册时才显示提示。
- 启动时不再弹出 Finder 扩展未就绪提示，减少普通用户首次安装后的干扰。
- 补齐标准 macOS AppIcon 10 个槽位，改善 Launchpad 首次显示透明或延迟刷新的情况。
- 菜单栏图标改为居中绘制并略微放大，改善与系统菜单栏图标的视觉尺寸一致性。
- GitHub Actions 生成的 DMG 明确标记为未签名 CI 测试包，避免误当作公开分发包。

### 分发
- 公开新用户验证只接受 Developer ID Application 签名、公证并 staple 的 Universal DMG。
- Apple Development 签名或 ad-hoc ZIP 只用于开发机快速验证，不作为普通新用户安装验证依据。

---

## [0.1.6] - 2026-07-28

### 新增
- FinderSync extension 自动保留最近 100 条本地诊断记录，主 App 启动后自动同步，无需手动运行日志脚本。
- 「复制诊断信息」和反馈 Issue 自动附带最近的扩展菜单与文件创建诊断记录。

### 修复
- 允许其他 App 位于前台时，在真实桌面背景右键显示「新建文件」菜单。
- 菜单生成时固定模板和目标目录，避免点击子菜单时焦点或模板设置变化导致文件创建到错误位置。
- 目标目录缺失时不再猜测或回退到桌面，并在创建前重新检查目录有效性。

### 分发
- 本地打包脚本支持读取本机 `Scripts/dev-identity.sh` 中的 Team ID，用于开发机快速构建 FinderSync 验证包。

---

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

### 分发
- GitHub Release 可上传安装包：`dist/RightHere-0.1.5-20260619-2237.dmg`。
- 安装包 SHA-256：`fa6e9774f143d0f9d49b52419e2916ae7824e1279061c2c40c42332fecbb432a`。
- 详细安装和发布说明已同步到 `RELEASE_NOTES.md`。

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
