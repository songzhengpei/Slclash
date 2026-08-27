<p align="center">
  <strong>简体中文</strong> · <a href="README_EN.md">English</a>
</p>

# SlClash

SlClash 是基于 [FlClash](https://github.com/chen08209/FlClash) 与 [Mihomo](https://github.com/MetaCubeX/mihomo) 持续裁剪、重构和重新设计的 Android 代理客户端。

它只做 Android，只维护 `arm64-v8a`。我们不想再做一个仅仅“能把 Mihomo 跑起来”的外壳，而是希望维护一款自己愿意长期依赖、持续审视细节，并认真对待性能、功耗和交互体验的移动端客户端。

## 我们围绕 Mihomo 做什么

SlClash 的使命，是在 Android 上可靠承载 Mihomo 的完整语义，而不是在内核之上再发明一套私有的“简化代理语义”。

Mihomo 的配置、Provider、策略组、规则和运行时状态，既是能力来源，也是 SlClash 判断真实状态的依据。只要一份配置能够被当前版本的 Mihomo 裸核运行，SlClash 的目标就是不改写其语义地接纳它，并把 Provider 节点、策略组和规则纳入同一条运行链路。Mihomo 随版本新增或调整配置字段、协议与运行时能力后，我们会在完成 Android 生命周期和兼容性验证后持续跟进，而不是另造一套不兼容的替代方案。

这也定义了项目的边界：

- Mihomo 负责代理内核、规则引擎与配置语义；SlClash 负责 Android 上的可靠承载、移动交互、生命周期、性能、订阅工作流和可观察性。
- 完整承载 Mihomo 语义是长期方向。我们会努力提高覆盖度，但不会用“天然、即时 100% 支持未来所有功能”这样的口号替代验证和维护。
- 项目只维护 Android 与 `arm64-v8a`，不重新建设桌面端、系统托盘、桌面热键、桌面系统代理或发行版包装。真实的跨平台需求，则通过与成熟桌面客户端兼容的数据迁移能力来解决。
- 统一订阅中心属于订阅整理、迁移和恢复能力，不改变也不替代 Mihomo 的内核语义。

## 维护与反馈

SlClash 仍在持续维护。真实设备上的稳定性、兼容性和日常体验，是我们最关心的反馈。

欢迎通过 [GitHub Issues](https://github.com/songzhengpei/Slclash/issues) 或邮件 [nudymanu@gmail.com](mailto:nudymanu@gmail.com) 联系我。明确的故障、兼容问题和体验不足会继续修复；新功能不会机械地照单添加，而会结合 Mihomo 语义一致性、Android 项目边界、长期维护成本和真实需求具体评估。

## 项目背景

Android 上围绕 Mihomo 的客户端并不少，但数量不等于精品。我们仍然缺少一款自己愿意长期依赖、每天打开也不会厌倦的客户端：代理切换要可靠，启动要顺畅，后台要克制，内存与耗电要合理，界面也要经得起长期使用。

因此，SlClash 不以堆叠功能数量为目标。性能、省电和内存控制不是发布之后才补做的优化，而是功能本身；一次不必要的刷新、一个没有边界的后台任务、一段网络切换后的陈旧状态，都属于需要认真处理的产品问题。

我们也把审美当作工程的一部分。专业工具可以保持足够的信息密度，同时拥有清晰的层级、克制的材质和舒适的触控路径。SlClash 希望做一套经得起时间考验、又能随着设计语言持续演进的界面，而不是停留在“功能能用即可”的工程面板。

## 界面预览

截图来自 Android 正式版的真实运行界面。所有 IP、订阅、节点、Provider、账号和设备相关信息均已使用不可逆的实色遮挡脱敏。

<p align="center">
  <img src="docs/images/readme/dashboard-dark-idle.jpg" width="30%" alt="深色主题未运行仪表盘">
  <img src="docs/images/readme/dashboard-dark-running.jpg" width="30%" alt="深色主题运行中仪表盘">
  <img src="docs/images/readme/dashboard-dark-paused.jpg" width="30%" alt="深色主题智能暂停仪表盘">
</p>

<p align="center">
  <img src="docs/images/readme/dashboard-light-idle.jpg" width="30%" alt="浅色主题未运行仪表盘">
  <img src="docs/images/readme/dashboard-light-running.jpg" width="30%" alt="浅色主题运行中仪表盘">
  <img src="docs/images/readme/dashboard-light-paused.jpg" width="30%" alt="浅色主题智能暂停仪表盘">
</p>

<p align="center">
  <img src="docs/images/readme/proxies-light.jpg" width="30%" alt="代理组页面">
  <img src="docs/images/readme/profiles-light.jpg" width="30%" alt="订阅配置页面">
  <img src="docs/images/readme/media-check.jpg" width="30%" alt="流媒体与健康检测页面">
</p>

<p align="center">
  <img src="docs/images/readme/backup-and-restore.jpg" width="30%" alt="备份与恢复页面">
  <img src="docs/images/readme/about.jpg" width="30%" alt="关于页面">
  <img src="docs/images/readme/smart-auto-stop.png" width="30%" alt="智能暂停设置">
</p>

## 统一订阅中心：把短期入口变成可长期维护的订阅资产

现实中的订阅并不总是一个可以保存多年、始终有效的 URL。阅后即焚链接、多个机场订阅、自建节点、外部 Provider，以及不断变化或失效的入口，往往同时存在。它们分散在手机、桌面和不同备份中之后，重新整理、迁移和恢复的成本会越来越高。

[Mihomo Subscription Vault](https://github.com/songzhengpei/mihomo-subscription-vault) 正是为此设计的私人订阅快照中心。它目前已经以 MIT 协议开放源代码，使用 Cloudflare Workers + R2 部署，可将不同格式和生命周期的上游来源整理为固定的 Provider 地址，并保留不可变版本、历史回滚和完整备份导出能力。客户端只需要保存稳定入口，不必反复追逐短期上游链接。

同一条 Provider 地址可以供 SlClash、Clash Verge Rev、OpenClash 等 Mihomo 客户端使用；中心导出的订阅归档也可以直接通过 SlClash 的恢复入口导入。再结合 Clash Verge Rev 备份兼容能力，就形成了 SlClash、Clash Verge Rev 与统一订阅中心之间清晰的迁移和备份路径。

这个中心面向私有部署：订阅地址、访问令牌和节点资产应当掌握在使用者自己的 Cloudflare 环境中。项目已经公开，可以直接查看实现并自行部署；后续仍会继续完善格式兼容、恢复行为和跨客户端工作流。

## 为什么要兼容 Clash Verge Rev 备份

[Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) 已经是一款成熟而优秀的桌面客户端，在界面、功能、兼容性和资源管理上都有扎实积累。SlClash 没有必要在复杂的桌面环境中重复建设同一套能力，但手机和桌面也不应该各自维护一份互不相通的订阅。

因此，SlClash 可以导入 Clash Verge Rev 的订阅备份，SlClash 导出的订阅母包也可以导入 Clash Verge Rev，实现手机与桌面之间的双向订阅迁移。

WebDAV 备份沿用 Clash Verge Rev 使用的 `/clash-verge-rev-backup` 目录约定，让跨客户端备份共享同一个明确入口，而不是再制造一套孤立目录。恢复订阅时，SlClash 只更新相关订阅数据，并保护应用设置、脚本、规则和自定义策略组，避免一次迁移误伤其他本地状态。

## 为手机重新设计，而不是简单换色

FlClash 为项目提供了优秀的跨平台与 Material You 基础；SlClash 则选择把设计资源集中到 Android 手机这一种形态上。我们保留代理客户端需要的信息密度，同时重新组织启动、暂停、恢复、模式切换、订阅选择、策略组选择和流量观察等高频路径，让常用操作离手指更近，让状态变化更容易确认。

界面使用统一的圆角、间距、字阶、语义状态色和模块化卡片体系。仪表盘、代理、配置、工具、底部导航、弹层和对话框不是彼此独立的页面拼装，而是共享同一套视觉与交互语言。重要状态醒目但不过度喧闹，次要信息保持可查而不争夺注意力，触控区域和页面节奏也围绕单手使用持续调整。

浅色、深色、纯黑、动态色和自定义主题并非简单反色：卡片层级、边框、填充、状态色、图表、导航与系统栏会共同响应主题。以后我们仍会持续打磨系统材质、信息密度和模块化展示，做一套经常使用也不显疲惫、版本更新后仍有新鲜感的界面。

## 性能、省电与内存是功能本身

SlClash 做过的大量优化，并不是一句笼统的“轻量化”口号，而是对平台范围、刷新调度、缓存边界、页面重建、网络切换和 VPN 生命周期逐项收紧：

- **平台裁剪：** 只保留 Android 与 `arm64-v8a`，移除桌面平台、系统托盘、桌面热键、桌面系统代理、Rust IPC 和发行版包装等无关链路，减少构建体积与运行复杂度。
- **按页面和生命周期调度：** 首页流量探测仅在服务运行、页面可见且应用处于前台时工作；日志和请求采用推送与批量刷新，高频数据使用固定长度缓存、节流和防抖，避免后台空转和全局 UI 连续重建。
- **空闲启动更克制：** 服务未运行时，冷启动不再为了界面展示提前拉起远程核心进程。Phase 4 的一台实测设备上，这条路径避免了约 45 MB 的远程进程 PSS；这是特定设备基线，不包装成所有设备都相同的宣传数字。
- **重建范围可控：** 高频运行状态被隔离到真正依赖它的组件；无收益的周期刷新已移除。项目使用真实 `FrameTiming` 审计页面流畅度，也不会为了表面上的切页速度，无条件让所有离屏页面常驻内存。
- **代理选择即时而稳定：** 选择节点后界面立即反馈，同一策略组的连续操作独立防抖，不同组互不阻塞；运行时 Provider 节点、所有权校验和快照新鲜度共同避免陈旧数据覆盖最新选择。
- **VPN 生命周期少做无用功：** 原生层是 VPN 状态的权威来源。运行中重新连接会复用现有远程进程、会话与 TUN，避免重复启动；智能暂停只移除 TUN 并保留会话与核心，离开可信网络后无需完整冷启动。
- **网络与检测有明确边界：** 网络切换会更新本地状态、清理陈旧连接并抑制短时间重复触发；健康检测使用并发上限、结果缓存和慢节点冷却，避免反复测试已经失效或处于冷却期的节点。

项目提供基于真实 Android 设备的 Phase 4 性能审计工具，覆盖启动、内存、导航、代理组、IPC、VPN 生命周期和后台行为；详见 [性能测试说明](tools/perf/README.md)。兼容性报告、Phase 4 结项和字体系统记录见 [docs/README.md](docs/README.md)。

## 围绕真实使用场景的功能

### 智能暂停

连接到家庭、公司、旁路由等可信 IP/CIDR 网络时自动暂停 VPN，离开后自动恢复。它带有防抖、重复操作保护和会话级手动恢复保护，避免自动状态与用户操作互相争抢。

### 独立的流媒体与健康检测

GPT、YouTube 和健康检测是三个独立模式。打开页面不会自动发起检测，运行一种模式也不会连带触发其他模式。结果按模式缓存，健康检测还会复用缓存，并冷却连续超时或高延迟节点。

检测节点来自 Mihomo 运行时的真实叶子节点数据，包括 Provider 下载的节点，而不是只搜索静态配置文件。

### 订阅、代理与资源管理

代理页支持策略组展开、节点选择、单节点与整组延迟检测；配置页集中展示订阅状态并提供直接管理入口；资源页负责 GEOIP、GEOSITE、MMDB、ASN 及更新计划。网络概览则汇集实时速率、流量趋势、常用站点延迟和路由区域提示，让运行状态能够被看见和判断。

更多能力仍在开发中，但每一项新增功能都会先回答两个问题：它是否符合 Mihomo 的原始语义，以及它是否真正改善 Android 上的长期使用体验。

## 获取

正式版和测试版安装包见 [GitHub Releases](https://github.com/songzhengpei/Slclash/releases)。

本项目仅支持 Android `arm64-v8a`。自行构建前请阅读仓库内的 [`AGENTS.md`](AGENTS.md)；README 不展开个人开发环境中的 SDK 路径。

## 致谢

SlClash 建立在 [FlClash](https://github.com/chen08209/FlClash) 的跨平台、Material You 项目基础，以及 [Mihomo](https://github.com/MetaCubeX/mihomo) / Clash.Meta 生态之上。

感谢原项目作者和社区长期提供的内核、客户端基础与公开讨论。FlClash 选择服务多平台，SlClash 选择把 Android 与 `arm64-v8a` 做深；这不是对原项目的否定，而是在同一基础上针对不同使用场景做出的取舍。
