---
title: "结构化日志规范"
weight: 78
---

# 结构化日志规范

这页给文档读者一个当前可执行的日志契约，而不是理想化的大而全字段表。

核心原则只有三条：

1. Logs 负责事件文本和业务决策，不替代 Metrics 和 Traces。
2. `trace_id` / `span_id` 是 Trace 到 Log 的主关联键。
3. 服务、环境、Kubernetes 资源信息优先作为 Resource Attributes 或 Collector enrichment，不要在每条请求日志里手工重复。

---

## 最小日志基线

所有结构化日志共享这组基础字段：

| 字段 | 作用 |
|---|---|
| `timestamp` | 事件发生时间 |
| `severity_text` | 日志级别 |
| `logger.name` | 日志分类 |
| `message` | 人可读事件文本 |
| `caller` | 调试辅助字段 |
| `trace_id` | Trace 关联键 |
| `span_id` | Span 关联键 |

说明：

- `message` 是当前推荐字段，不再使用 `body` 作为新日志字段。
- `caller` 可以保留，但它不是核心 observability 维度。
- `request_id` 属于 legacy 兼容字段，新日志不推荐继续扩展它。

---

## logger.name 分类

当前 DevFlow 统一使用以下日志分类：

| `logger.name` | 用途 |
|---|---|
| `http.access` | 正常 HTTP 请求完成日志 |
| `http.error` | HTTP 4xx / 5xx / panic 日志 |
| `business.event` | 业务变更和控制面动作 |
| `release.lifecycle` | Manifest / Release / Intent 生命周期 |
| `runtime.state` | runtime 同步、observer、runtime 操作 |
| `external.call` | 下游 HTTP / Kubernetes / Argo / Tekton 调用 |
| `db.query` | Repository 查询和持久化 |
| `worker.lifecycle` | 后台 worker 生命周期 |
| `service.lifecycle` | 进程启动、关闭、客户端初始化 |

日志分类统一看 `logger.name`，不要看 `caller`。

---

## HTTP 日志

### `http.access`

用于正常请求完成。

最小字段：

- `http.request.method`
- `http.route`
- `url.path`
- `http.response.status_code`

可选字段：

- `http.request.body.size`
- `http.response.body.size`

当前普通 2xx access log 有意保持极简，不默认重复这些字段：

- `service.name`
- `service.namespace`
- `service.version`
- `deployment.environment.name`
- `component`
- `result`
- `event.outcome`
- `duration_ms`
- `client.address`
- `user_agent.original`
- 请求级 `devflow.*.id`

示例：

```json
{
  "severity_text": "INFO",
  "timestamp": "2026-05-11T08:00:00Z",
  "logger.name": "http.access",
  "message": "http request",
  "caller": "routercore/gin.go:210",
  "trace_id": "2e71abb92e031efc2a7a1c4280959f4b",
  "span_id": "abc123def456",
  "http.request.method": "GET",
  "http.route": "/api/v1/releases/:id",
  "url.path": "/api/v1/releases/123",
  "http.response.status_code": 200,
  "http.response.body.size": 244
}
```

### `http.error`

用于 HTTP 4xx、5xx 和 panic recovery。

最小字段仍然是：

- `http.request.method`
- `http.route`
- `url.path`
- `http.response.status_code`

约束：

- 4xx 通常记为 `WARN`
- 5xx 通常记为 `ERROR`
- 具体错误文本直接进 `message`
- 不再额外拆 `error` / `panic` 字段

---

## 业务和系统日志

### `business.event`

用于 create / update / delete、sync、控制面操作。

推荐字段：

- `operation`
- `resource`
- `result`
- `resource_id`
- 稳定的 `devflow.*.id`

普通 get/list 成功路径不应打 `business.event`。标准读路径通常只需要：

- `http.access` / `http.error`
- `db.query`
- trace spans

### `release.lifecycle`

用于 manifest / release / intent 生命周期事件。

推荐字段：

- `operation`
- `resource`
- `result`
- `resource_id`
- `devflow.release.id`
- `devflow.manifest.id`
- `intent_id`

### `runtime.state`

用于 runtime read model、observer、operator action。

推荐字段：

- `operation`
- `resource`
- `result`
- `resource_id`
- `devflow.application.id`
- `devflow.environment.id`
- `runtime_spec_id`

### `external.call`

用于下游边界。

推荐字段：

- `operation`
- `resource`
- `dependency`
- `dependency_kind`
- `dependency_operation`
- `result`

可选字段：

- `duration_ms`
- `http.request.method`
- `url.path`
- `http.response.status_code`
- `error_code`

### `db.query`

用于 repository 查询和持久化。

推荐字段：

- `operation`
- `resource="database"`
- `db.system`
- `db.collection`
- `db.operation`
- `result`

可选字段：

- `resource_id`
- 稳定资源 ID
- `duration_ms`
- `error_code`

### `worker.lifecycle` / `service.lifecycle`

分别用于后台 worker 生命周期和服务启动关闭。

共享字段：

- `operation`
- `resource`
- `result`

---

## 字段归属边界

### 应用代码负责

- HTTP 请求事实
- 业务操作事实
- 稳定的 DevFlow 业务对象 ID

### OpenTelemetry SDK / instrumentation 负责

- `trace_id`
- `span_id`
- `service.name`
- `service.namespace`
- `service.version`

### OpenTelemetry Collector 负责

- `k8s.*`
- `host.*`
- `cloud.*`
- 运行时环境附加资源信息

Kubernetes 字段不应在业务代码里写死，因为 Pod、Node、Namespace、Cluster 都是运行时落点，不是业务事实。

---

## 低价值路径过滤

默认不记录这些低价值路径的普通成功请求：

- `/health`
- `/healthz`
- `/readyz`
- `/livez`
- `/metrics`
- `/favicon.ico`
- `/internal/status`
- `/debug/pprof*`
- `/swagger*`

但以下信号必须保留：

- 4xx 请求
- `status_code >= 500`
- `WARN` / `ERROR`
- 关键业务操作日志

这样做的原因很直接：这些路径通常来自 kubelet、Prometheus、调试工具，频率高、价值低，会污染日志检索和图表。

---

## 不要这样做

不要把这些字段作为日志分类维度或 Loki stream label：

- `caller`
- `trace_id`
- `span_id`
- `request_id`
- `url.path`
- `error_message`
- `stacktrace`

这些字段可以存在于日志 JSON 里，但不应该成为高基数索引维度。

---

## 典型排障路径

1. 先用 Metrics 发现 error rate / latency 问题
2. 通过 exemplar 跳到对应 Trace
3. 再通过 `trace_id` / `span_id` 找到日志

Logs 的职责不是重复一遍完整 trace，而是补充 trace 上没有的人类可读事件文本和业务决策。

---

## 关联阅读

- [公共 Attributes](../attributes/)
- [Labels / Attributes 规范](../standard/)
- [信号标签矩阵](../signal-label-matrix/)
