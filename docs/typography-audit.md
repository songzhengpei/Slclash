# Slclash 字体系统全仓审计（第一阶段）

> 审计日期：2026-07-19
> 审计范围：`lib/**/*.dart`、`pubspec.yaml`、本地化生成物与字体资源；统计默认排除 `lib/**/generated/`，生成物仅用于确认语言现状。
> 本报告只描述现状和迁移依据，不确定最终字号表，也不修改业务代码。

## 1. 执行摘要

当前项目**尚不存在真正统一的字体系统**。`SurgeTypography` 已提供 20 个语义/页面混合角色，并接入 AppBar 和少量公共组件，是可继续演进的基础；但 `ThemeData.textTheme` 未由同一基础规模显式构建，大部分页面仍直接写 `fontSize`、`fontWeight`、`height` 和 `letterSpacing`。Dashboard 还拥有独立的响应式字号算法，旧 `TextStyle` 扩展可继续任意加粗、改字号或切等宽字体。

本次扫描 317 个 Dart/YAML/本地化相关文件候选，其中非 generated 的 `lib` Dart 源码中发现：

- `fontSize:` 183 处（150 处为直接数字字面量）；
- `fontWeight:` 154 处（140 处为直接 `FontWeight.*`）；
- `letterSpacing:` 186 处（全部为数字字面量，且全部为 `0`）；
- `fontFamily:` 7 处；
- `TextStyle(...)` 构造 39 处；大量样式来自 `TextTheme.copyWith`、主题属性和组件参数，因此构造数不能代表全部硬编码；
- `SurgeTypography` 消费 28 处；`TextTheme` 访问 214 处；字体扩展调用 4 处；
- `w700` 45 处、`w800` 15 处、`bold` 3 处，重字重明显过量；
- 小于 11sp 的直接字号 15 处，最小为 8sp；
- `maxLines: 1` 130 处、`TextOverflow.ellipsis` 122 处，是英文与字体放大风险的重要信号。

本文将“字体硬编码总量”定义为全部 `fontSize:` 赋值 183 处；其中可直接认定为数值硬编码的为 150 处。这样可同时覆盖通过变量、响应式函数和组件参数间接传入字号的场景，避免只统计 `TextStyle` 构造而严重漏报。

## 2. 当前字体架构

当前实际数据流不是单向，而是五个事实来源并行：

1. Flutter/Material 默认 `ThemeData.textTheme`：`ThemeData` 未提供项目自定义 `textTheme`，标准组件和 214 处访问依赖框架默认值。
2. `SurgeTypography`：位于 `lib/widgets/surge/surge_tokens.dart`，同时绑定字号、字重、行高、字距和颜色。
3. 页面与组件硬编码：150 处直接字号字面量和 140 处直接字重，是当前覆盖面最大的事实来源。
4. 字体变换扩展：`toBold`、`toSoftBold`、`toJetBrainsMono`、`adjustSize` 可在调用点继续派生新样式。
5. Dashboard 响应式字号：`DashboardResponsiveLayout.type/legacyType` 按视口缩放基础数值，并将系统字体缩放上限钳制到 1.15。

另有 `FontFamily`/pubspec 字体资源作为字体族来源，但它不定义完整字号层级，故不单列为第六套字体系统。

结论：`SurgeTypography` 不是简单废弃项，应**保留概念并重构**。它已有语义入口和 `ThemeExtension` 宿主，但角色中混入 `dashboardMicro/dashboardTiny/dashboardLoading` 等页面专用命名，且直接绑定颜色、与 Material `TextTheme` 无共同基础规模，现阶段只能算部分覆盖的迁移层。

## 3. 字体定义入口

| 入口 | 主要位置 | 覆盖范围 | 判断 |
|---|---|---|---|
| Material `TextTheme` | `lib/application.dart:161-231`、`lib/common/context.dart:69` | 全局默认及大量旧组件 | 全局，但字号来自 Flutter 默认，不是项目唯一源 |
| `SurgeTypography` | `lib/widgets/surge/surge_tokens.dart:341-473` | AppBar、Surge 公共组件、备份恢复、部分 Dashboard | 可复用，需拆分排版与颜色并接入统一基础规模 |
| Surge context 扩展 | `lib/widgets/surge/surge_theme_extension.dart:256-265` | title/body/caption/sectionTitle 快捷访问 | 可保留 API 方向，覆盖角色太少 |
| 文本样式扩展 | `lib/common/text.dart:5-17` | 任意 `TextStyle` | `toLight/toLighter` 属颜色职责；`toBold/adjustSize` 会绕过语义约束，应限制或废弃 |
| 字号缩放扩展 | `lib/common/num.dart:21-27` | 编辑器等旧代码 | 非标准缩放，`ap` 只应用系统增量的 50%，`mAp` 更会封顶，建议废弃 |
| Dashboard 响应式体系 | `lib/views/dashboard/dashboard_layout.dart:57-260` | Dashboard 两张主卡及子组件 | 几何与字体有意识分离，可复用响应式思想；字体 Token 数值不应留在页面 |
| 导航主题 | `lib/application.dart:88-101` | Material NavigationBar | 11sp、w500/w600 硬编码，绕过 Surge/Typography |
| 自定义底部导航 | `lib/widgets/surge/surge_bottom_nav.dart:153,235-236` | 当前 Soft OS 导航 | 又一套 11sp、w600/w700、height 1 |
| 自定义 Tab | `lib/widgets/tab.dart:495-517` | Tab | `_kFontSize`、高亮字重私有常量，页面语义之外 |
| 字体资源 | `pubspec.yaml` | 全局资源 | JetBrains Mono Regular、Twemoji；普通 UI 使用系统字体 |

没有发现 Google Fonts。没有发现按 locale 切换主字体族的代码。Material/Cupertino 的字体覆盖主要集中于 AppBar、NavigationBar、DropdownMenu 及局部 `DefaultTextStyle`。

## 4. 硬编码统计

| 项目 | 词法出现数 | 直接字面量 | 说明 |
|---|---:|---:|---|
| `TextStyle(` | 39 | — | 不含 `copyWith`、主题属性和间接 style |
| `fontSize:` | 183 | 150 | 报告所称字体硬编码总量采用 183 |
| `fontWeight:` | 154 | 140 | 其余为条件/变量 |
| `letterSpacing:` | 186 | 186 | 全部为 0，重复噪声显著 |
| `fontFamily:` | 7 | 7 | JetBrains Mono 2、Twemoji 4、系统 monospace 1 |
| `TextTheme` 使用 | 214 | — | 包含 `context.textTheme` 与 `Theme.of(...).textTheme` |
| `SurgeTypography` 使用 | 28 | — | 其中多处紧接 `copyWith` 再修改字号/行高/颜色 |
| 字体扩展调用 | 4 | — | `toBold/toSoftBold/toJetBrainsMono/adjustSize` |
| `DefaultTextStyle` | 12 | — | 包含 Animated/merge |
| `TextSpan` | 53 | — | Rich text、提示消息及错误信息 |
| `RichText` | 2 | — | emoji 文本组件为主要入口 |

硬编码热点：

| 文件 | `fontSize` | `fontWeight` | 结论 |
|---|---:|---:|---|
| `views/profiles/profiles.dart` | 22 | 16 | 主界面中字号最混乱，管理 Sheet/预览/状态/操作密集 |
| `views/profiles/media_check.dart` | 21 | 19 | 字体最重，15 处 w800 集中于此文件的大部分 |
| `widgets/surge/surge_tokens.dart` | 19 | 10 | Token 自身数值，合理但目前混合颜色/页面角色 |
| `dashboard/widgets/network_overview_card.dart` | 12 | 3 | 大量响应式 `layout.type(...)`，仍属页面字号源 |
| `dashboard/widgets/surge_dashboard_hero.dart` | 11 | 11 | 私有视觉层级多，且多次覆盖 Token |
| `views/resources.dart` | 9 | 7 | 11/14/14.5/15 与 height 1 混用 |

## 5. 字号分布

以下为直接数字字面量的 150 处，不包含 `layout.type(12)` 等表达式；后者仍已计入 183 总量。

| sp | 次数 | sp | 次数 | sp | 次数 |
|---:|---:|---:|---:|---:|---:|
| 8 | 1 | 9 | 1 | 10 | 12 |
| 10.5 | 1 | 11 | 32 | 12 | 23 |
| 13 | 23 | 13.5 | 2 | 14 | 17 |
| 14.5 | 1 | 15 | 19 | 15.5 | 1 |
| 16 | 4 | 17 | 7 | 18 | 4 |
| 19 | 1 | 20 | 1 |  |  |

分布集中在 11–15sp，但存在 8、9、10、10.5、13.5、14.5、15.5 等细碎档位。最小值 8sp 位于 `SurgeTypography.dashboardMicro`；即便仅用于密集 Dashboard，也低于易读性安全线，不适合作为普通信息，需在第二阶段单独决策。小于 11sp 的主要位置：

- `surge_tokens.dart:441,446,465`（Dashboard micro/tiny/loading）；
- `profiles/media_check.dart:1083,1258,1279,1364,1419,1476`（10/9sp 状态、图例与辅助信息）；
- `profiles/profiles.dart:679`、`widgets/setting.dart:138`、`views/logs.dart:260,273`；
- `surge_dashboard_card.dart:69`、`traffic_usage.dart:62`。

Dashboard 中另有 `layout.type(10/11/12/13/14/15/16)`、`legacyType(14/19)` 等运行时结果，实际字号会随宽度落在非整数值，不能只按上述静态表合并。

## 6. 字重分布

| 字重 | 次数 | 评价 |
|---|---:|---|
| w400 | 10 | 普通正文显式使用较少，更多正文依赖默认 weight |
| w500 | 25 | 控件/普通强调 |
| w600 | 42 | 标题和大量控件强调 |
| w700 | 45 | 全仓最高频显式字重，使用过量 |
| w800 | 15 | 几乎全部集中于媒体检测，明显偏重 |
| `bold` | 3 | 错误页 2 处、扩展定义 1 处 |
| 条件/变量 | 14 | 多数在 selected 状态切换 w500/w600/w700 |

`w700 + w800 + bold` 共 63 处（含扩展定义），约占全部 `fontWeight:` 的 41%。结论是重字重被过度使用，尤其以选中状态、卡片标题、数字和媒体检测状态来代替字号/颜色/空间层级。字体最重的页面是 `profiles/media_check.dart`，其次是 `profiles/profiles.dart` 和 Dashboard Hero。

## 7. 行高与字距分布

明确出现在文字样式附近的行高包括：`1`/`1.0`、`1.08`、`1.1`、`1.2`、`1.25`、`1.35`、`1.4`。其中 `height: 1`/`1.0` 候选超过 40 处，集中于 Profiles、Resources、Proxies、Dashboard、底部导航、设置项和 Surge tokens；项目确实存在大量过紧行高。

典型位置：`resources.dart:361,374,516,531,615,626,718`，`profiles.dart:669,681,756,769,820,952,961,1090`，`media_check.dart:1098,1193`，`connection/item.dart:112,262`，`surge_bottom_nav.dart:153,236`，`surge_dashboard_hero.dart:800,974,1134,1190`。

全部 186 个 `letterSpacing:` 都是 `0`。这说明它不是当前有差异的设计变量，而是大量重复声明；未来应由基础 Token 统一表达，业务层无需反复书写。

## 8. 字体族与等宽字体使用

`pubspec.yaml` 声明：

- `JetBrainsMono`：`assets/fonts/JetBrainsMono-Regular.ttf`；
- `Twemoji`：`assets/fonts/Twemoji.Mozilla.ttf`。

7 处 `fontFamily:` 分布：JetBrains Mono 2 处（编辑器、文本扩展），Twemoji 4 处（emoji 渲染/网络检测/Overview Card），`'monospace'` 1 处（错误页代码文本）。JetBrains Mono 和系统 monospace 均用于编辑器/规则/错误代码等技术内容；Twemoji 只为 emoji glyph。未发现等宽字体用于普通标题、正文、按钮或导航，当前适用范围总体合理。

风险是 `toJetBrainsMono` 可被任意样式调用，且 `FontFamily` 直接暴露；第二阶段应把等宽能力收敛为 `technical` 语义角色。Twemoji 是字形回退的特殊场景，不应并入普通 typography role。

## 9. 语义分类结果

| 语义类别 | 当前主要样式 | 差异/冲突 | 候选角色 |
|---|---|---|---|
| 页面/AppBar 标题 | Surge 20/w700；旧 Theme 默认；Dialog 18/w600 | 同级来源不同，AppBar 偏重 | `screenTitle`/`appBarTitle` |
| 页面分区标题 | Surge 13/w600；页面 13–15/w600/w700 | 字号与颜色均不稳定 | `sectionTitle` |
| 卡片标题 | Surge 17/w700；常见 13/14/15 w600/w700 | 类别内部差异最大之一 | `cardTitle` |
| 列表主标题 | Surge 16/default；页面 14–16 w500–w700 | 默认、w600、w700 混用 | `rowTitle` |
| 列表副标题/辅助 | Surge 13/default；页面 10–13 w400/w500 | 过小、height 1 多 | `supporting` |
| 正文 | Material bodyMedium/bodyLarge；Surge 15/default | 两套来源，数值未共源 | `body` |
| 按钮/Tab/导航 | 11–15、w500–w700 | 选中态常用加粗；导航两套实现 | `controlLabel`/`navigationLabel` |
| Chip/Badge | Surge 12/w700/height 1；页面 9–13 w600–w800 | 极端重且紧 | `controlLabel` 或独立 `badgeLabel` |
| 主要指标 | Surge 18/w700；Dashboard 12–18 w700 | 受空间驱动，语义与密度混杂 | `metricLarge`/`metric` |
| 技术数据 | JetBrains Mono、系统 monospace、Material body | 用途合理但入口分散 | `technical` |
| 极小辅助 | 8–10.5，多为 Dashboard/媒体检测 | 可读性风险最高 | `micro`（需严格限制） |
| 错误/警告 | 颜色状态 + 12–16 bold/w600 | 字重随页面决定 | 正常语义角色 + semantic color |
| 空状态/弹窗 | Token emptyState、Theme defaults、18/w600 | 入口不统一 | `supporting`/`dialogTitle`（候选新增） |

同一语义用途存在多套字体最严重的是卡片标题、Badge/状态标签、指标和列表主标题。不同语义错误共用的典型是 11–12sp 同时承担导航、状态、指标单位、按钮和辅助说明。

## 10. 重复和冲突样式

- 11sp 出现 32 次，横跨导航、辅助说明、状态、按钮和数据标签，数值相同但语义完全不同。
- 12sp 与 13sp 各 23 次，既用于正文/副标题，也用于 Badge、指标、技术数据；迁移不能只做数值查找替换。
- `SurgeTypography.cardTitle` 为 17/w700，但多数实际卡片标题为 13–15/w600/w700。
- `SurgeTypography.rowTitle` 为 16/default weight，而列表实现常主动设 w600/w700。
- `appBarTitle` 20/w700 与目标方向中的 Medium 强调冲突；Dialog 自建 18/w600。
- Token 被 `copyWith(fontSize: 12/10, height: 1/1.25)` 二次改写（如 `surge_data_list.dart`、`surge_section.dart`、Overview Card），说明角色粒度或角色选择不够。
- 186 处 `letterSpacing: 0` 是完全重复的低价值局部声明。
- Dashboard 同时使用 Surge dashboard roles、`layout.type(...)`、直接 `TextStyle` 和 `copyWith(fontSize...)`，内部也不是单源。

特殊场景不能简单合并：代码编辑器/规则表达式、Twemoji 字形、图表刻度、极窄状态图例、延迟/流量等紧凑技术数据，以及需要随宽度重排的 Dashboard 指标。

## 11. 四个主界面之间的差异

按当前移动端核心入口审计 Dashboard、Proxies、Profiles、Tools（Resources 为 Tools 下的重要二级入口）：

| 主界面 | 特征 | 主要问题 |
|---|---|---|
| Dashboard | 独立响应式字号、Surge Token 与直接硬编码混用 | 最复杂的缩放策略；系统缩放封顶 1.15；8–10sp 微字 |
| Proxies | 多用列表/卡片组件，但 providers/setting/list 局部 w700+height 1 | 选中态偏重，名称/Provider 行英文风险高 |
| Profiles | 22 个字号入口、16 个字重入口；管理 Sheet 和预览密集 | 主界面中字号最混乱，固定高度和单行截断多 |
| Tools | 更依赖通用列表和 TextTheme | 相对一致，但下钻页面各自定义样式，整体一致性是假象 |

如果将 Resources 视为独立主入口，它有 9 个字号、7 个字重以及大量 height 1，是四/五个顶层视图中密度最高的一类。

## 12. 二级页面之间的差异

- `profiles/media_check.dart`：21 个字号入口、19 个字重入口、15 个 w800；是全项目最重、最碎的页面。
- `theme.dart`：主题预览自身构建 12–15sp 多套样式，预览需求与真实 UI 样式混在一起。
- `backup_and_restore.dart`：相对更多复用 Surge row/badge，但仍以 copyWith 修改颜色和局部 w700。
- `logs.dart`：10/10.5sp + height 1，密集技术数据可理解，但 200% 缩放风险高。
- `error.dart`：15/16 bold 与 12 monospace，语义清楚但没有走统一角色。
- `overwrite` 系列：Material TextTheme、JetBrains Mono、Dropdown/Tab 私有字重混合，是技术表单特殊迁移组。
- `about.dart`、changelog dialog：存在 w800，视觉明显重于普通二级页面。

## 13. 中英文适配风险

全仓结构信号：130 处 `maxLines: 1`、122 处 ellipsis、211 处数字固定宽度、292 处数字固定高度、166 个 Row，而 Wrap 仅 10 个。并非每一处都是问题，但说明当前主要策略是压缩/截断，而不是为长文本重排。

| 风险 | 等级 | 主要位置与原因 |
|---|---|---|
| Profiles 管理 Sheet、媒体检测筛选/状态卡 | 高 | 密集 Row、固定 30–46 高度、9–13sp、单行/ellipsis；英文功能名明显更长 |
| Dashboard Hero 模式/策略/网络检测 | 高 | 单行信息层级、固定卡高、字号与图标强绑定，且缩放封顶掩盖溢出 |
| 自定义底部导航 | 高 | 11sp、height 1、固定槽位；英文导航标签长度差异大 |
| Resources 卡片/操作栏 | 高 | 多个 11sp、height 1、固定 30/34/40 高度与 Row |
| Proxies provider/group 行 | 中高 | 节点/Provider 名不可控，右侧延迟和动作占位，常用单行 ellipsis |
| 设置项右侧值、Select pill | 中高 | 长英文值与左右控件竞争空间，选中态还加粗 |
| Tab/Chip/Badge | 中 | 私有字号、固定高、Wrap 使用少；小屏/130% 后风险上升 |
| Dialog/错误页/空状态 | 低到中 | 多数正文可换行，但标题和操作按钮仍需英文回归 |

当前生成本地化仍包含 en、zh_CN、ja、ru；本阶段未删除语言。字体系统只需设计中英文，但静态审计显示代码并无英文专用字号缩小分支，这是好事；风险主要来自布局约束。术语一致性需要第二阶段前由产品侧确认，特别是 Profile/Configuration、Proxy/Node、Provider、Media Check/Detection 等概念。

## 14. 系统字体缩放风险

### 100%

当前基准视觉大体可运行，但 8–10sp、height 1 和高字重已经造成易读性问题。Profiles/Media Check 的层级主要靠粗细与微字号维持。

### 130%

固定高度按钮、卡片标题、底部导航、资源操作栏和 Provider 行开始出现垂直裁切或水平 ellipsis。Dashboard 将系统缩放钳制到 1.15，因此不会完整响应 130%，属于可访问性缺口而不是“安全”。

### 200%

高风险组件包括：

- `views/dashboard/dashboard.dart:21`：整页通过 `textScalerForDashboard` 将上限限制为 1.15，无法达到 200%；
- `views/profiles/profiles.dart:2262-2267`：`FittedBox` + `TextScaler.noScaling` 明确绕过系统缩放；
- `views/profiles/media_check.dart`：大量 30–46dp 固定高度控件和单行 9–15sp 文本；
- `views/resources.dart`：固定 30/34/40dp 与 height 1；
- `widgets/surge/surge_bottom_nav.dart`：固定导航槽 + height 1；
- `views/logs.dart`、`views/connection/item.dart`：密集 Row + height 1；
- `network_overview_card.dart:1531`、`traffic_usage.dart:40`：FittedBox 会缩小文字以保布局，违背用户放大意图；
- `common/num.dart` 的 `ap/mAp`：手动减半或封顶系统缩放效果；
- 图标和文字共用固定高度的 Surge pill/control dock/setting tile。

`manager/theme_manager.dart:83-97` 会取系统与应用设置的最大比例并重建 `MediaQuery.textScaler`，方向上支持缩放；但上述局部 clamp、noScaling、FittedBox 和手动 `.ap/.mAp` 使行为不一致。

## 15. 当前 Typography 实现的可复用部分

- `SurgeTheme` 已是 ThemeExtension，并由 `ThemeData.extensions` 全局注入，宿主机制可保留。
- `SurgeTypography` 已经用角色而非文件名表达多数常见语义：title/body/caption/sectionTitle/appBarTitle/cardTitle/rowTitle/rowSubtitle/field/metric/badge/micro。
- AppBar 已从 `surge.typography.appBarTitle` 读取，证明公共组件迁移链路可行。
- `SurgeTypography.lerp` 支持主题插值。
- Dashboard 的 geometry/type 分离和窄宽重排判断值得保留，但不应继续拥有独立字号真值。
- JetBrains Mono/Twemoji 资源用途清晰，无需引入大型中文字体；主界面继续系统字体栈合理。

需要重构之处：排版 Token 不应固定绑定颜色；`title/body/caption` 与 Material `TextTheme` 应来自同一基础规模；Dashboard 页面专用角色应缩减或转成通用 metric/micro/technical；所有 role 的默认行高需显式、统一且支持 TextScaler。

## 16. 建议废弃或限制的接口

| 接口 | 建议 | 原因 |
|---|---|---|
| `TextStyleExtension.toBold` | 废弃 | 任意提升到 bold，绕过语义角色 |
| `toSoftBold` | 限制/废弃 | 仍由调用点决定字重 |
| `adjustSize` | 废弃 | 任意相对字号，且依赖 `fontSize!` |
| `NumExt.ap/mAp` | 废弃 | 非线性/封顶系统缩放，行为不可预测 |
| `toJetBrainsMono` | 收敛 | 迁移至 `technical` role，避免普通文案误用 |
| 页面 `copyWith(fontSize/fontWeight/height)` | 静态限制 | 直接制造新字体角色；仅颜色/状态装饰可按白名单允许 |
| 页面 `letterSpacing: 0` | 禁止新增 | 应由 Token 一次定义 |
| `TextScaler.noScaling`/Dashboard clamp | 需专项决策 | 直接影响无障碍，不能作为普通布局修复手段 |
| Dashboard `type(number)` | 保留算法、移除数值真值 | 响应式缩放可保留，输入应来自 Token |

## 17. 下一阶段需要决策的问题

1. 基础字号与行高是否按系统字体栈 + Material 3 映射，还是保留部分现有 11/13/15/17/20 节奏？
2. AppBar/card/metric 是否从 w700 下调至 w600，媒体检测 w800 是否全部取消？
3. 8–10sp 是否允许作为图表/极密技术数据的例外；最低可读字号和例外白名单是什么？
4. `SurgeTypography` 是继续作为 `SurgeTheme` 子对象，还是拆成独立 ThemeExtension；如何与 `TextTheme` 共用基础规模？
5. Typography 与 semantic color 如何拆分，现有 `copyWith(color:)` 是否作为允许的状态覆盖？
6. Dashboard 是否必须完整支持 200% 系统缩放；若必须，哪些卡片允许重排/滚动/增高？
7. 是否新增 `dialogTitle`、`badgeLabel`、`code`/`technicalSmall`、`chartLabel` 等角色，避免滥用 micro/controlLabel？
8. 英文术语表与允许 ellipsis 的语义范围需先确定；导航和操作按钮是否允许两行？
9. 静态检查的目录边界和白名单：Token/Theme、Painter、第三方适配、Twemoji 是否豁免？
10. 后续是否仅维护 en/zh_CN；语言删除不属于当前阶段，但会影响布局回归矩阵。

## 18. 附录：主要文件和使用位置清单

| 文件/位置 | 用途 | 当前来源 | 风险 | 初步处理 |
|---|---|---|---|---|
| `application.dart:88-101` | NavigationBar label | 硬编码 11/w500-600 | 中英文高、缩放高 | 映射 navigationLabel |
| `application.dart:221` | AppBar title | Surge appBarTitle | w700 偏重 | 保留入口、重定值 |
| `surge_tokens.dart:341-473` | 20 个 typography roles | Surge | 颜色耦合、页面角色 | 重构保留 |
| `common/text.dart:5-17` | 样式派生 | 扩展 | 绕过 Token | 废弃/限制 |
| `common/num.dart:21-27` | 手动字号缩放 | 扩展 | 200% 不完整 | 废弃 |
| `dashboard_layout.dart:57-260` | Dashboard type scale | 页面算法 | 独立数据源、1.15 clamp | 保留响应式思想 |
| `profiles/profiles.dart` | 主 Profile、管理 Sheet、预览 | 大量硬编码 | 最高混乱度 | 按子组件分批迁移 |
| `profiles/media_check.dart` | 检测、结果、筛选、指标 | 大量硬编码 | w800、9–10sp、固定高 | 最高优先级专项迁移 |
| `dashboard/widgets/surge_dashboard_hero.dart` | 核心状态与控制 | Token+硬编码+响应式 | 单行/固定高/重字重 | 公共 metric/control roles |
| `dashboard/widgets/network_overview_card.dart` | 图表、延迟、流量 | Token+layout.type+TextStyle | FittedBox、微字 | chart/technical 特例 |
| `resources.dart` | 资源列表与操作 | 硬编码 | height 1、固定高 | row/supporting/control |
| `proxies/providers.dart` | Provider 行 | 硬编码 11–15/w700 | 长名称竞争空间 | rowTitle/supporting |
| `proxies/list.dart` | 节点列表 | TextTheme+硬编码 | 名称/延迟单行 | row/technical |
| `widgets/setting.dart` | 设置项 | 硬编码 | 固定高、右侧长值 | 公共 setting typography |
| `widgets/tab.dart:495-517` | Tab label | 私有常量 | 独立字重 | controlLabel |
| `surge_bottom_nav.dart` | 底部导航 | 硬编码 | 11/w700/height1 | navigationLabel |
| `widgets/dialog.dart:36-38` | Dialog title | 18/w600 | 与 AppBar/Theme 分离 | dialogTitle 候选 |
| `pages/error.dart:36-102` | 错误标题/代码 | bold + monospace | 未 Token 化 | error color + title/technical |
| `pages/editor.dart:315-316` | 编辑器 | bodyLarge + JetBrains Mono | 特殊合理 | technical |
| `widgets/text.dart:94-129` | Emoji 富文本 | Twemoji copyWith | 字形特殊 | 白名单保留 |
| `providers/action.dart:307-558` | Dialog/Sheet 状态文案 | 硬编码 w700/w800/行高 | 二级覆盖重 | dialog/body/supporting |

### 审计问题的直接回答

1. 统一字体系统：没有，仅有部分语义化的 SurgeTypography。
2. 事实数据源：5 个。
3. SurgeTypography：保留其语义入口和 ThemeExtension 宿主，重构而非原样保留或完全替换。
4. 字体最重：Media Check；其次 Profiles、Dashboard Hero。
5. 字号最混乱：Profiles 主页面；Media Check 紧随其后。
6. 差异最大语义：卡片标题、Badge/状态标签、指标、列表主标题。
7. 最小字号：8sp，不适合作为常规信息，只可能作为严格受限的密集图表例外。
8. w700/bold：过度使用；加上 w800 共 63 处。
9. height 1：是，文字样式候选超过 40 处，覆盖多个核心页面。
10. 等宽字体：当前未发现明显误用。
11. 英文最易溢出：媒体检测控件、Profiles 管理 Sheet、Dashboard 控件、底部导航、Resources 操作栏、Provider 行。
12. 200% 最易损坏：Dashboard、Media Check、Profiles noScaling/FittedBox、Resources、底部导航、Logs/Connection 密集行。
13. 可直接映射：AppBar、section、row title/subtitle、body、field、badge、metric、technical 和 navigation label。
14. 特殊场景：编辑器/规则代码、Twemoji、图表刻度、极窄状态图例、响应式技术指标。
15. 人工决策：基础规模/最低字号/重字重策略、TextTheme 与 Surge 关系、颜色拆分、200% 重排标准、英文术语与截断政策、静态检查白名单。

## 审计边界与可复现口径

本报告是静态词法扫描加重点文件人工复核。`height:` 同时用于布局和文字，故不把全仓 `height:` 总数冒充文字行高；只报告在文字样式上下文确认的值和风险位置。`copyWith` 全仓共有大量非字体用途，因此只对明确修改字体字段的调用纳入结论。行号基于 2026-07-19 工作区版本，后续修改可能漂移。

本阶段仅新增本报告，未修改 Dart、ThemeData、ARB、本地化文件或任何界面行为。
