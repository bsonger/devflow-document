---
title: "Labels / Attributes 规范"
weight: 73
---

# 标签使用规范

DevFlow 的 Metrics、Traces、Logs 使用统一的标签体系，确保三者可以互相关联。

---

## Metrics（指标）标签

### 必须带的标签

每个指标都应该带这些标签，方便后续筛选和聚合：

- `service_name` — 哪个服务产生的指标
- `http_method` — 什么请求方法
- `http_route` — 请求的路径模板
- `status_code` — HTTP 响应状态码

### 不能作为标签的字段

有些字段不适合做标签，因为值太多会导致存储爆炸：

| 字段 | 为什么不行 |
|------|-----------|
| user_id | 用户可能有几千万，每个用户一条时间线 |
| request_id | 每个请求唯一，基数无限 |
| ip_address | IP 数量无界 |

这些字段应该放在 Logs 或 Traces 里，而不是 Metrics 标签里。

---

## Traces（链路）标签

### Span 基本信息

- `trace_id` — 整个链路的唯一标识
- `span_id` — 当前环节的唯一标识
- `parent_span_id` — 上一环节的标识
- `duration_ms` — 这个环节花了多少时间

### 业务上下文

- `application_id` — 涉及哪个应用
- `manifest_id` — 涉及哪个构建
- `release_id` — 涉及哪个发布

这样从链路里可以直接看到：这个请求在处理哪个应用的发布。

---

## Logs（日志）标签

### 必须带的字段

- `timestamp` — 日志时间
- `level` — 日志级别（info/warn/error）
- `message` — 日志内容
- `service_name` — 哪个服务打印的

### 关联字段

- `trace_id` — 关联到对应的链路
- `span_id` — 关联到链路中的具体环节

---

## 三者怎么关联

```mermaid
graph LR
    Metrics["Metrics<br/>看到错误率飙升"] -->|exemplar.trace_id| Trace["Trace<br/>找到具体请求"]
    Trace -->|trace_id| Log["Log<br/>查看错误详情"]
```

排查问题的典型路径：

1. Grafana 仪表盘看到错误率飙升（Metrics）
2. 点击指标上的 exemplar，跳转到对应 Trace
3. 从 Trace 找到具体服务，再跳转到该服务的 Log

三个系统通过统一的 `trace_id` 和 `service_name` 串在一起。
