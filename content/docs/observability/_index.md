---
title: "可观测性"
weight: 70
---

# 📡 可观测性

这组文档面向正在维护 `devflow-service` 的工程师，重点不是介绍 OTel 概念，而是回答 4 个更直接的问题：

1. 五个服务各自该观测什么
2. 新服务或新链路怎么接入 Metrics / Logs / Traces
3. 发布链路怎样做到“看到异常后能一路查下去”
4. 线上出问题时应该先看指标、链路，还是日志

---

## 先选入口

| 你现在要做什么 | 先看哪组 |
|------|------|
| 理解 DevFlow 的观测边界 | [字段契约](#字段契约) |
| 给运维 / 平台 / SRE 定义 signal 分层责任 | [Signal 分层规范](#signal-分层规范) |
| 给一个服务补观测能力 | [接入实现](#接入实现) |
| 对照五个服务查漏补缺 | [服务约定](#服务约定) |
| 排查发布慢、发布失败、运行时异常 | [排障运行](#排障运行) |

---

## 字段契约

这组文档回答的是：字段叫什么、该由谁注入、DevFlow 的三种信号各自最少要带什么。

| 文档 | 单一职责 |
|------|----------|
| [技术栈与组件矩阵](component/) | 先看清 observability 技术栈和组件边界 |
| [字段命名与来源边界](contracts/attributes/) | 只看公共命名和来源归属 |
| [信号字段契约](contracts/standard/) | 看 Metrics / Traces / Logs 的完整字段契约 |
| [信号标签矩阵](contracts/signal-label-matrix/) | 直接查三种信号的必需字段和禁止项 |
| [结构化日志规范](contracts/logging/) | 日志字段、`logger.name`、`caller`、日志分类契约 |

推荐阅读顺序：

- 先读 [字段命名与来源边界](contracts/attributes/)
- 再读 [信号字段契约](contracts/standard/)
- 然后看 [结构化日志规范](contracts/logging/)
- 最后把 [信号标签矩阵](contracts/signal-label-matrix/) 当速查表

如果你当前正在判断“某个字段到底该来自服务代码、SDK 还是 Collector”，这一组应该先读。

---

## 接入实现

这组文档回答的是：规范已经定了，DevFlow 服务代码和 Collector 应该怎么落地。

| 文档 | 单一职责 |
|------|----------|
| [Collector 模板](collector/) | 平台侧该如何注入公共资源字段 |
| [Go 接入示例](go-example/) | 一个 Go 服务的最小接入骨架 |
| [OTel 接入检查清单](onboarding-checklist/) | 新服务接入时的最小验收清单 |

推荐阅读顺序：

- 先看 [Collector 模板](collector/)
- 再看 [Go 接入示例](go-example/)
- 然后对照 [结构化日志规范](contracts/logging/)
- 最后按 [OTel 接入检查清单](onboarding-checklist/) 验收

如果你正准备给某个新 API、异步任务或发布阶段补链路，这一组最有用。

---

## 服务约定

这组文档回答的是：不是新服务模板，而是当前 DevFlow 既有五个服务到底该重点观测什么。

| 文档 | 单一职责 |
|------|----------|
| [现有服务字段清单](service-checklist/) | 把规范落到五个服务的关键字段、关键日志、关键指标上 |

---

## 排障运行

这组文档回答的是：系统已经上线了，断流、慢链路、发布失败时先看哪里。

| 文档 | 单一职责 |
|------|----------|
| [发布链路 Trace 示例](release-trace-example/) | 定义一条“可排障”的发布链路应该长什么样 |
| [Collector 生产排障 Runbook](collector-runbook/) | 排查 Metrics / Logs / Traces 断流、缺字段、延迟升高 |
| [发布失败排障剧本](release-failure-playbook/) | 按发布阶段缩小失败范围并判断根因 |

---

## 建议你怎么读

如果你当前在做的是：

- **补一个服务的基础观测能力**
  - 先看 [技术栈与组件矩阵](component/)
  - 再看 [OTel 接入检查清单](onboarding-checklist/)
  - 最后对照 [现有服务字段清单](service-checklist/)
- **排查一次发布异常**
  - 先看 [发布链路 Trace 示例](release-trace-example/)
  - 再看 [发布失败排障剧本](release-failure-playbook/)
  - 最后回到 [结构化日志规范](contracts/logging/) 补字段缺口
- **统一平台规范**
  - 先看 [字段命名与来源边界](contracts/attributes/)
  - 再看 [信号字段契约](contracts/standard/)
  - 最后用 [信号标签矩阵](contracts/signal-label-matrix/) 做验收

---

## Signal 分层规范

这组文档主要给运维、平台、SRE 看，回答的是“字段该落在哪一层、哪一类信号该带什么、哪些字段不该出现”。

这里的 `signals/` 是目标态路由和 ownership 摘要；字段命名和 baseline requirement 仍以 [字段契约](contracts/) 下的详细页面为准。

| 文档 | 单一职责 |
|------|----------|
| [Signal 分层规范](signals/) | 先看五层 ownership 和整体阅读顺序 |
| [HTTP 字段边界](signals/http/) | 看请求边界字段该由框架、服务、SDK 还是 Collector 负责 |
| [Metrics 字段规范](signals/metrics/) | 看指标标签的 required / optional / forbidden |
| [Logs 字段规范](signals/logs/) | 看结构化日志字段最小集和来源边界 |
| [Traces 字段规范](signals/traces/) | 看 span 属性、错误标记和传播责任 |
| [Signals 运维验收表](signals/validation/) | 看平台和运维如何逐项验收整套 signal 规范 |

---

## 全部文档

按阅读目的分组后的完整索引：

- 字段契约
  - [技术栈与组件矩阵](component/)
  - [字段命名与来源边界](contracts/attributes/)
  - [信号字段契约](contracts/standard/)
  - [信号标签矩阵](contracts/signal-label-matrix/)
  - [结构化日志规范](contracts/logging/)
- Signal 分层规范
  - [Signal 分层规范](signals/)
  - [HTTP 字段边界](signals/http/)
  - [Metrics 字段规范](signals/metrics/)
  - [Logs 字段规范](signals/logs/)
  - [Traces 字段规范](signals/traces/)
  - [Signals 运维验收表](signals/validation/)
- 接入实现
  - [Collector 模板](collector/)
  - [Go 接入示例](go-example/)
  - [OTel 接入检查清单](onboarding-checklist/)
- 服务约定
  - [现有服务字段清单](service-checklist/)
- 排障运行
  - [发布链路 Trace 示例](release-trace-example/)
  - [Collector 生产排障 Runbook](collector-runbook/)
  - [发布失败排障剧本](release-failure-playbook/)
