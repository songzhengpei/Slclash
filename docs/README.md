# Docs

SlClash 的已发布说明。产品介绍仍以仓库根目录的 [`README.md`](../README.md) / [`README_EN.md`](../README_EN.md) 为准；本地开发约定见 [`AGENTS.md`](../AGENTS.md)。

| 目录 | 内容 |
|---|---|
| [`images/readme/`](images/readme/) | README 截图 |
| [`phase4/`](phase4/) | Phase 4 性能与生命周期审计、基线、结项 |
| [`mihomo/`](mihomo/) | Mihomo 配置语义兼容性报告 |
| [`design/`](design/) | 字体系统设计与迁移记录 |

## Phase 4

A–E 已结项。当前工作是 4F.0（后台/功耗归因基线）；4G 未开始。命令与测量规则见 [`tools/perf/README.md`](../tools/perf/README.md)。

| 阶段 | 状态 | 入口 |
|---|---|---|
| 4A Startup | CLOSED | [closeout 用 a1 / a2](phase4/phase4-a1-startup.md) · [baseline](phase4/phase4-a0-baseline.md) |
| 4B Navigation | CLOSED | [closeout](phase4/phase4-b-final-closeout.md) |
| 4C Proxy / Group | CLOSED | [closeout](phase4/phase4-c-final-closeout.md) |
| 4D Runtime IPC | CLOSED | [closeout](phase4/phase4-d-final-closeout.md) |
| 4E VPN Lifecycle | CLOSED | [closeout](phase4/phase4-e-final-closeout.md) |
| 4F Background / Power | CURRENT (4F.0 only) | [baseline](phase4/phase4-f0-background-power-baseline.md) |

## Mihomo compatibility

Phase 1–2CD 报告已冻结，作为配置管线与 CI 门禁的说明，不是进行中的任务列表。

- [Phase 1](mihomo/mihomo-compatibility-phase1.md)
- [Phase 2A](mihomo/mihomo-compatibility-phase2a.md)
- [Phase 2B](mihomo/mihomo-compatibility-phase2b.md)
- [Phase 2CD](mihomo/mihomo-compatibility-phase2cd.md)

## Design

字体系统已落地。以迁移报告为准；审计稿和冻结规范保留为当时的依据，不再描述当前未迁移状态。

- [迁移报告](design/typography-migration-report.md)
- [系统设计（冻结稿）](design/typography-system-design.md)
- [全仓审计](design/typography-audit.md)
