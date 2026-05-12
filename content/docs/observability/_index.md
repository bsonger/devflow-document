---
title: "可观测性"
weight: 70
---

# 📡 可观测性

DevFlow 的 observability 文档主要回答四类问题：

1. 基础规范是什么
2. 新服务怎么接入
3. 现有服务最少要补哪些字段
4. 线上出问题时先去哪排查

---

## 先选入口

| 你现在要做什么 | 先看哪组 |
|------|------|
| 理解规范边界 | [字段契约](#字段契约) |
| 接一个新服务 | [接入实现](#接入实现) |
| 收口现有服务字段 | [服务约定](#服务约定) |
| 排查线上问题 | [排障运行](#排障运行) |

---

## 字段契约

这组文档回答的是：字段叫什么、该由谁注入、三种信号各自最少要带什么。

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

---

## 接入实现

这组文档回答的是：规范已经定了，代码和 Collector 应该怎么落地。

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

---

## 服务约定

这组文档回答的是：不是新服务模板，而是当前 DevFlow 既有服务到底还缺什么字段。

| 文档 | 单一职责 |
|------|----------|
| [现有服务字段清单](service-checklist/) | 把规范落到现有服务的字段补齐任务上 |

---

## 排障运行

这组文档回答的是：系统已经上线了，断流、慢链路、发布失败时先看哪里。

| 文档 | 单一职责 |
|------|----------|
| [发布链路 Trace 示例](release-trace-example/) | 定义一条“可排障”的发布链路应该长什么样 |
| [Collector 生产排障 Runbook](collector-runbook/) | 排查 Metrics / Logs / Traces 断流、缺字段、延迟升高 |
| [发布失败排障剧本](release-failure-playbook/) | 按发布阶段缩小失败范围并判断根因 |

---

## 全部文档

按阅读目的分组后的完整索引：

- 字段契约
  - [技术栈与组件矩阵](component/)
  - [字段命名与来源边界](contracts/attributes/)
  - [信号字段契约](contracts/standard/)
  - [信号标签矩阵](contracts/signal-label-matrix/)
  - [结构化日志规范](contracts/logging/)
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
