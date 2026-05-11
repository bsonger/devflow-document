---
title: "结构化日志规范"
weight: 78
---

# 结构化日志规范

<span class="df-badge">Logs</span> <span class="df-badge">logger.name</span> <span class="df-badge">caller</span> <span class="df-badge">Contract</span>

这页给文档读者一个当前可执行的日志契约，而不是理想化的大而全字段表。

这页主要解决一个问题：

> **一条可排障的结构化日志最少该长什么样。**

核心原则只有三条：

1. Logs 负责事件文本和业务决策，不替代 Metrics 和 Traces。
2. `trace_id` / `span_id` 是 Trace 到 Log 的主关联键。
3. 服务、环境、Kubernetes 资源信息优先作为 Resource Attributes 或 Collector enrichment，不要在每条请求日志里手工重复。

这里的约束再说一次：`trace_id` / `span_id` 不是“有最好”，而是新日志契约里的必需字段。

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
- `trace_id` 和 `span_id` 必须来自当前 span context；缺少它们的日志不满足当前 DevFlow 结构化日志基线。

---

## 字段等级

先把最容易混淆的两类字段拆开：

| 字段 | 等级 | 作用 |
|---|---|---|
| `timestamp` | 必需 | 时间定位 |
| `severity_text` | 必需 | 严重级别 |
| `logger.name` | 必需 | 日志分类主键 |
| `message` | 必需 | 人可读事件文本 |
| `caller` | 必需 | 调试定位字段 |
| `trace_id` | 必需 | Trace -> Log 关联主键 |
| `span_id` | 必需 | Span -> Log 关联主键 |

补充说明：

- `logger.name` 决定“这是什么类型的日志”，它是分类字段。
- `caller` 决定“这条日志是从哪里打出来的”，它只是调试字段。
- 两者不能互相替代。日志归类看 `logger.name`，不要看 `caller`。

---

## `logger.name` 规则

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

## `caller` 规则

`caller` 和 `logger.name` 不是一回事：

- `logger.name` 是稳定分类
- `caller` 是源码位置

`caller` 的使用规则：

- 每条结构化日志都应保留 `caller`
- `caller` 只用于调试定位
- `caller` 不能作为日志分类依据
- `caller` 不能作为 metrics label
- `caller` 不能作为 Loki stream label
- `caller` 不能作为 Grafana dashboard variable

如果你要区分 `http.access` 和 `http.error`，看 `logger.name`；
如果你要知道日志来自哪段代码，再看 `caller`。

---

## HTTP 日志

### `http.access`

用于正常请求完成。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="http.access"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `http.request.method`
- `http.route`
- `url.path`
- `http.response.status_code`

建议字段：

- `http.response.body.size`

可选字段：

- `http.request.body.size`

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

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="http.error"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `http.request.method`
- `http.route`
- `url.path`
- `http.response.status_code`

建议字段：

- `http.request.body.size`
- `http.response.body.size`

约束：

- 4xx 通常记为 `WARN`
- 5xx 通常记为 `ERROR`
- 具体错误文本直接进 `message`
- 不再额外拆 `error` / `panic` 字段

---

## 业务和系统日志

### `business.event`

用于 create / update / delete、sync、控制面操作。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="business.event"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource`
- `result`

建议字段：

- `resource_id`
- 稳定的 `devflow.*.id`

普通 get/list 成功路径不应打 `business.event`。标准读路径通常只需要：

- `http.access` / `http.error`
- `db.query`
- trace spans

### `release.lifecycle`

用于 manifest / release / intent 生命周期事件。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="release.lifecycle"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource`
- `result`

建议字段：

- `resource_id`
- `devflow.release.id`
- `devflow.manifest.id`
- `intent_id`

### `runtime.state`

用于 runtime read model、observer、operator action。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="runtime.state"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource`
- `result`

建议字段：

- `resource_id`
- `devflow.application.id`
- `devflow.environment.id`
- `runtime_spec_id`

### `external.call`

用于下游边界。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="external.call"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource`
- `dependency`
- `dependency_operation`
- `result`

建议字段：

- `dependency_kind`

可选字段：

- `duration_ms`
- `http.request.method`
- `url.path`
- `http.response.status_code`
- `error_code`

### `db.query`

用于 repository 查询和持久化。

必需字段：

- `timestamp`
- `severity_text`
- `logger.name="db.query"`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource="database"`
- `db.system`
- `db.operation`
- `result`

建议字段：

- `db.collection`

可选字段：

- `resource_id`
- 稳定资源 ID
- `duration_ms`
- `error_code`

### `worker.lifecycle` / `service.lifecycle`

分别用于后台 worker 生命周期和服务启动关闭。

共享必需字段：

- `timestamp`
- `severity_text`
- `logger.name`
- `message`
- `caller`
- `trace_id`
- `span_id`
- `operation`
- `resource`
- `result`

额外约束：

- `worker.lifecycle` 只能用于后台 worker 的启动、停止、重试、退出
- `service.lifecycle` 只能用于进程启动、关闭、客户端初始化、配置装载

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

- [字段命名与来源边界](../attributes/)
- [信号字段契约](../standard/)
- [信号标签矩阵](../signal-label-matrix/)
