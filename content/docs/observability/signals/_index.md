---
title: "Signal 分层规范"
weight: 72
bookCollapseSection: true
---

# Signal 分层规范

这组文档面向运维、平台、SRE。它不解释概念，只回答 3 个执行层问题：

1. Metrics、Logs、Traces 分别该带哪些字段
2. 哪些字段是必需、可选、禁止
3. 字段最终该由哪一层负责注入或补齐

如果你当前在统一运维、平台、SRE 的 signal ownership 规则，先看这里；如果你当前在做服务接入或排障，先回到上一层的 [可观测性](../) 选择对应入口。

这里的 `signals/` 只给出目标态的路由和 ownership 摘要；字段命名和基线要求仍以 `contracts/` 下的详细契约页为准。

---

## 五层归属模型

DevFlow 的目标态信号字段统一按下面五层归属，不在服务代码里“谁方便谁写”：

| 层级 | 责任方 | 只负责什么 |
|------|--------|------------|
| 1 | 框架或 middleware 自动生成 | HTTP / RPC / runtime 等请求边界内天然可得的字段 |
| 2 | 服务显式写入 | 只有业务代码知道的业务身份、阶段、结果、错误语义 |
| 3 | SDK 自动传播或补充 | trace 上下文、资源字段、语言运行时通用属性 |
| 4 | OTel Collector enrichment | 进程外统一补齐的环境、集群、部署、管道侧元数据 |
| 5 | Prometheus scrape / target metadata | 仅在抓取时可确定的 target、job、instance 等采集元数据 |

约束只有一条：字段应该由最早且最稳定能确定它的那一层负责。下游可以补充，不能改写上游已经确定的业务语义。

---

## 三类信号怎么分

| 信号 | 必需字段 | 可选字段 | 禁止字段 | 默认 owner |
|------|----------|----------|----------|------------|
| Metrics | 能稳定聚合和告警的低基数字段 | 只用于固定切片的附加标签 | 高基数、原始 ID、自由文本、完整错误堆栈 | 服务、Prometheus、Collector |
| Logs | 能定位请求、组件、结果、错误原因的结构化字段 | 便于排障但不是所有日志都需要的上下文 | 与 `message` 重复的大段文本、不可解析 blob、无 key 的拼接字段 | 服务、框架、SDK、Collector |
| Traces | 能还原链路边界、状态、耗时、错误的 span 属性 | 帮助细化阶段和下游依赖的补充属性 | 指标式高频重复明细、敏感原文、大体积 payload | 框架、服务、SDK、Collector |

判定原则：

- `required`：缺失后会直接影响聚合、关联或排障闭环。
- `optional`：对部分服务或部分场景有价值，但不能成为全局前提。
- `forbidden`：会造成高基数、敏感信息泄漏、语义冲突或不可维护。

---

## owner 应该怎么判

| owner | 应出现在哪些字段 |
|------|------------------|
| 框架 | `http.request.method`、`http.route`、`server.address`、`http.response.status_code`、基础耗时边界 |
| 服务 | `service.name` 之外的业务身份、发布阶段、任务结果、业务错误码、域内对象状态 |
| OTel SDK | `trace_id`、`span_id`、上游 trace / span 上下文传播、语言运行时资源字段、通用 telemetry SDK 字段 |
| OTel Collector | `k8s.*`、`deployment.environment.name`、集群/节点/namespace 等平台侧 enrichment |
| Prometheus | `job`、`instance`、scrape target 相关元数据 |

禁止把第 4 层和第 5 层能稳定补齐的环境字段回写进服务代码；也禁止把只有第 2 层知道的业务语义期待给 Collector 或 Prometheus 猜出来。

---

## 推荐阅读顺序

| 先读什么 | 你会解决什么问题 |
|------|------------------|
| [HTTP 字段边界](http/) | 请求入口有哪些字段应由框架、服务、SDK、Collector 分担 |
| [Metrics 字段规范](metrics/) | 指标标签哪些能聚合、哪些必须禁止 |
| [Logs 字段规范](logs/) | 结构化日志最小字段集和 owner 边界 |
| [Traces 字段规范](traces/) | span 属性、错误标记、链路传播该落在哪一层 |
| [Signals 运维验收表](validation/) | 按 signal 和 owner 对整套规范做平台验收 |

---

## 文档清单

- [HTTP 字段边界](http/)
- [Metrics 字段规范](metrics/)
- [Logs 字段规范](logs/)
- [Traces 字段规范](traces/)
- [Signals 运维验收表](validation/)
