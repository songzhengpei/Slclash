# Slclash 字体系统全项目迁移报告

日期：2026-07-19  
状态：已完成。本报告记录当时的一次性迁移结果，不是待办清单。

## 1. 完成范围

已一次性迁移公共组件、普通页面、Dashboard、Profiles 与 Media Check。业务逻辑、数据模型、网络与检测算法未调整。

## 2. 正式架构

应用使用 `buildSlclashTextTheme()` 构造完整 Material `TextTheme`，并以独立 `SurgeTypography` ThemeExtension 暴露 15 个语义角色。业务代码统一通过 `context.typography.<role>` 读取。

## 3. 公共组件

按钮、列表、输入、弹窗、Tab、设置项、空状态及 Surge 控件均已迁移到语义角色。控件状态只改变颜色等视觉状态，不再改变字体结构。

## 4. 普通页面

Logs、Resources、Connections、Proxies、About、Access、Backup、Theme、Profiles overwrite 等页面已清除页面级字号和字重定义。

## 5. Dashboard

删除 `typographyScale`、`type()`、`legacyType()` 和 `textScalerForDashboard()`。Dashboard 不再限制页面 TextScaler，也不再用 FittedBox 缩小文字；窄屏继续通过结构重排处理。

## 6. Profiles

Profiles 主页面、编辑页、管理 Sheet、状态胶囊与 overwrite 页面已使用语义角色；原 `TextScaler.noScaling` 和文字 FittedBox 已删除。

## 7. Media Check

标题、筛选、结果、状态和辅助信息均已迁移；原 w700/w800、9sp 和固定文字结构已清除。检测算法未修改。

## 8. 中英文

中文与英文共享同一套角色、字号、字重和行高，不存在按语言缩小字号的分支。

## 9. 字体缩放

普通文本完整继承系统 1.0、1.3 与 2.0 TextScaler。页面级 clamp、`TextScaler.noScaling` 和文字 FittedBox 均为零。

## 10. 删除的旧接口

删除 `ap`、`mAp`、`adjustSize`、`toBold`、`toSoftBold`、`toJetBrainsMono`，以及 Dashboard 字号计算入口。

## 11. 删除的兼容层

删除 `SurgeTheme.typography`、`context.surge`、`SurgeTextStyles` 和 `LegacySurgeTypographyCompatibility`。正式入口只保留 `context.typography`。

## 12. AST 静态检查

新增 `typography_source_contract_test.dart`，使用 analyzer AST 检查生产 Dart 源码中的 TextStyle 构造、字体结构字段、旧扩展、TextScaler.noScaling 与 FittedBox。正反 fixture 均已覆盖。Beta 和 Release 工作流将该测试作为失败即中止的 CI step。

## 13. 永久白名单

- `lib/theme/typography/**`：字体基础设施。
- `lib/widgets/text.dart`：Twemoji renderer 的 `fontFamily`。
- `lib/views/dashboard/widgets/network_detection.dart`：Twemoji renderer 的 `fontFamily`。
- `lib/views/dashboard/widgets/network_overview_card.dart`：Twemoji renderer 的 `fontFamily`。
- `lib/pages/editor.dart`：第三方 CodeEditorStyle 适配所需的 `fontSize/fontFamily`，取值来自 `technical` 角色。
- `lib/widgets/open_container.dart`：非文字的 OpenContainer 转场 FittedBox。
- `lib/models/generated/**`：生成源码，不由手工规则改写。

## 14. 临时白名单

无。

## 15. 最终硬编码扫描

业务与公共组件中：直接 `TextStyle` 构造 0，`fontWeight` 0，`letterSpacing` 0，`TextScaler.noScaling` 0，旧字体扩展 0，Dashboard 字号计算 0。剩余 `fontSize/fontFamily` 仅为登记的编辑器与 Twemoji 适配；剩余 FittedBox 仅为非文字容器转场。

## 16. 测试

新增/修改字体架构、AST 门禁、Dashboard 布局、Media Check 和公共组件宿主测试。`flutter test` 共 559 项，全部通过。

## 17. Analyzer

`flutter analyze`：0 error、0 warning；保留 12 条与本轮无关的既有 info。

## 18. APK 与真机

`flutter build apk --debug --target-platform android-arm64` 成功。APK 安装成功，并明确启动 `com.slclash.app.dev/com.follow.clash.MainActivity`；包标志包含 `DEBUGGABLE`。

## 19. 结论

字体结构已集中到唯一基础设施，业务层只选择语义角色并允许颜色等非结构覆盖。全量测试、Analyzer、arm64 Debug 构建、安装和 Debug 包启动均通过。
