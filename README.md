<p align="center">
  <strong>简体中文</strong> · <a href="README_EN.md">English</a>
</p>

# SlClash

SlClash 是基于 [FlClash](https://github.com/chen08209/FlClash) 与 [Mihomo](https://github.com/MetaCubeX/mihomo) 持续裁剪、重设计的 Android 代理客户端。

它只做 Android，只维护 `arm64-v8a`。我们希望它不是另一个把 Mihomo 包进壳里的客户端，而是一款愿意长期使用、持续审视细节、认真处理性能与体验的移动端工具。

## 我们围绕 Mihomo 做什么

SlClash 的使命，是在 Android 上可靠承载 Mihomo 的完整语义，而不是在内核之上再发明一套私有的“简化代理语义”。

Mihomo 的配置、Provider、策略组、规则和运行时状态是能力来源，也是 SlClash 判断真实状态的依据。界面可以更适合手机，操作可以更直接，但不能因为 UI 简化就改变配置原本的含义，或让已有的 Mihomo 配置进入一套不兼容的方言。

这也定义了项目的边界：

- Mihomo 负责代理内核、规则和配置语义；SlClash 负责 Android 上的交互、生命周期、性能、订阅工作流与可观察性。
- 我们以完整承载 Mihomo 语义为长期方向，但不会声称对 Mihomo 未来出现的每一项能力都天然、即时实现 100% 覆盖。
- 项目只维护 Android 与 `arm64-v8a`，不会重新建设 Windows、macOS、Linux、系统托盘、桌面热键、桌面系统代理和发行版包装。
- 统一订阅中心属于订阅整理、迁移与恢复能力，不修改或替代 Mihomo 的内核语义。

## 维护与反馈

SlClash 仍在持续维护。真实设备上的稳定性、兼容性和日常体验，是我们最关心的反馈。

欢迎通过 [GitHub Issues](https://github.com/songzhengpei/Slclash/issues) 或邮件 [nudymanu@gmail.com](mailto:nudymanu@gmail.com) 联系我们。明确的故障和体验不足会继续修复；新功能不会机械照单添加，而会根据 Mihomo 语义一致性、Android 项目边界、维护成本和真实需求具体评估。

## 为什么继续维护这个客户端

Android 上围绕 Mihomo 的客户端并不少，但数量不等于精品。我们仍然希望有一款自己愿意长期依赖的客户端：代理切换可靠，启动足够顺畅，后台足够克制，内存和耗电保持合理，界面也经得起每天打开。

因此 SlClash 不以“功能越多越好”为目标。性能、省电和内存控制不是发布之后才做的附加优化，而是功能本身；一次不必要的刷新、一个没有边界的后台任务、一段网络切换后的陈旧状态，都属于需要认真处理的产品问题。

## 界面预览

截图来自 Android 正式版的真实运行界面。所有 IP、订阅、节点、Provider、账号和设备相关信息均已使用实色遮挡脱敏。

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
  <img src="docs/images/readme/media-check.jpg" width="30%" alt="流媒体检测页面">
</p>

<p align="center">
  <img src="docs/images/readme/backup-and-restore.jpg" width="30%" alt="备份与恢复页面">
  <img src="docs/images/readme/about.jpg" width="30%" alt="关于页面">
</p>

<p align="center">
  <img src="docs/images/readme/smart-auto-stop.png" width="65%" alt="智能暂停与可信网络设置">
</p>

## 统一订阅中心：订阅不应该被困在一个入口里

现实中的订阅并不总是一个可以保存多年、始终有效的 URL。阅后即焚链接、多个机场订阅、自建节点、外部 Provider，以及不断变化或失效的入口，往往同时存在。它们分散在手机、桌面和不同备份中之后，重新整理、迁移和恢复的成本会越来越高。

统一订阅中心正是从这个问题出发：把来源复杂、生命周期不同的订阅与节点整理成统一、可恢复的订阅集合。统一订阅中心生成的订阅归档，可以直接通过 SlClash 的恢复入口导入为订阅；再结合 Clash Verge Rev 的备份兼容能力，形成 SlClash、Clash Verge Rev 与统一订阅中心三方之间的迁移和备份路径。

统一订阅中心仍在完善，成熟后会开源。我们暂时不承诺具体日期，希望先把格式、恢复行为和跨客户端兼容性做扎实。

## 为什么要兼容 Clash Verge Rev 备份

手机和桌面不应该各自维护一份互不相通的订阅。SlClash 可以导入 Clash Verge Rev 的订阅备份，SlClash 导出的订阅母包也可以导入 Clash Verge Rev，从而在两个客户端之间双向迁移订阅。

WebDAV 备份沿用 Clash Verge Rev 使用的 `/clash-verge-rev-backup` 目录约定，让跨客户端备份拥有同一个明确入口，而不是再制造一套孤立目录。恢复订阅时，SlClash 只更新相关订阅数据，保护应用设置、脚本、规则和自定义策略组，避免一次迁移误伤其他本地状态。

## 为手机重新设计，而不是简单换色

SlClash 保留代理客户端需要的信息密度，但把启动、暂停、恢复、模式切换、订阅选择、策略组选择和流量观察这些高频操作放在更直接的位置。仪表盘、代理、配置、工具和底部弹层都重新按移动端触控与阅读习惯整理。

浅色、深色、纯黑、动态色和自定义主题不是简单反色：卡片层级、边框、填充、状态色、图表、底部导航与系统栏都会随主题重新处理。我们希望它仍然是一款专业工具，但不必看起来像临时拼起来的工程面板。

## 性能、省电与内存是功能本身

我们不使用容易随设备和版本失效的单一漂亮数字来概括性能，而是持续约束产生消耗的机制：

- 只保留 Android 与 `arm64-v8a`，移除桌面平台、系统托盘、桌面热键、桌面系统代理、Rust IPC 和分发器打包等无关链路。
- 连接、请求、日志和首页探测只在必要的页面与生命周期内刷新；高频事件使用固定长度缓存、节流和防抖，避免持续推动全局 UI 重绘。
- 网络切换会更新本地状态并清理陈旧连接，同时限制短时间重复触发。
- 健康观测使用并发上限、结果缓存、失败重试和慢节点冷却，避免反复测试已经处于冷却期的坏节点。
- 智能暂停在可信网络中优先通过 Android 原生 `smartStop` / `smartResume` 暂停和恢复 TUN，不必每次完整销毁并重建服务。
- 项目提供基于真实 Android 设备的 Phase 4 性能审计工具，覆盖启动、内存、导航、代理组、IPC、VPN 生命周期与后台行为；详见 [性能测试说明](tools/perf/README.md)。

## 围绕真实使用场景的功能

### 智能暂停

连接到家庭、公司、旁路由等可信 IP/CIDR 网络时自动暂停 VPN，离开后自动恢复。它带有防抖、重复操作保护和会话级手动恢复保护，避免自动状态与用户操作互相争抢。

### 流媒体与健康检测

GPT、YouTube 和健康检测是三个独立模式。打开页面不会自动发起检测，运行一种模式也不会连带触发其他模式。结果按模式缓存，健康观测还会复用缓存并冷却连续超时或高延迟节点。

检测节点来自 Mihomo 运行时的真实叶子节点数据，包括 Provider 下载的节点，而不是只搜索静态配置文件。

### 订阅、代理与资源

代理页支持策略组展开、节点切换、单节点与整组延迟测试；配置页提供当前订阅节点、流媒体检测和更直接的订阅管理入口；资源页负责 GEOIP、GEOSITE、MMDB、ASN 等资源及其自动更新。网络概览则集中展示实时速率、流量趋势、常用站点延迟和路由地区提示。

## 获取

正式版和测试版安装包见 [GitHub Releases](https://github.com/songzhengpei/Slclash/releases)。

本项目仅支持 Android `arm64-v8a`。自行构建前请阅读仓库内的 [`AGENTS.md`](AGENTS.md)；README 不展开个人开发环境中的 SDK 路径。

## 致谢

SlClash 建立在 [FlClash](https://github.com/chen08209/FlClash) 的项目基础与 [Mihomo](https://github.com/MetaCubeX/mihomo) / Clash.Meta 生态之上。

感谢原项目作者和社区长期提供的内核、客户端基础与公开讨论。SlClash 只是沿着个人 Android 使用需求继续裁剪、验证和打磨的一条分支。
