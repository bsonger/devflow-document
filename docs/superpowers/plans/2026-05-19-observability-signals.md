# Observability Signals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `content/docs/observability/signals/` documentation subtree that defines DevFlow's target-state metrics, logs, traces, and HTTP signal standards for platform and operations readers.

**Architecture:** Keep the existing `contracts/` pages intact as the general contract layer, then add a signal-first subtree for target-state operational standards. Build the subtree around one shared ownership model and one dedicated HTTP page so readers can answer field-level questions such as which HTTP access log fields are required, which metric labels are allowed, and which attributes must be platform-enriched.

**Tech Stack:** Hugo Markdown content, existing DevFlow observability docs, existing `contracts/standard.md` and `contracts/logging.md` terminology

---

### Task 1: Create Signals Index Page

**Files:**
- Create: `content/docs/observability/signals/_index.md`
- Modify: `content/docs/observability/_index.md`
- Reference: `docs/superpowers/specs/2026-05-19-observability-signals-design.md`

- [ ] **Step 1: Draft the new subtree index page**

Write `content/docs/observability/signals/_index.md` with:

```md
---
title: "Signal 分层规范"
weight: 81
---

# Signal 分层规范

这组文档定义 DevFlow observability 的目标形态规范，面向运维、平台和 SRE 读者。重点不是介绍 OTel 概念，而是回答三类问题：

1. 一个字段应该出现在 metrics、logs 还是 traces
2. 这个字段是必须、可选，还是禁止出现在某类 signal
3. 这个字段该由框架、服务代码、Prometheus、OTel SDK 还是 OTel Collector 负责

## 统一责任分层

所有 signal 页面都按同一套来源边界描述字段归属：

1. 框架或 middleware 自动生成
2. 服务显式写入
3. SDK 自动传播或补充
4. OTel Collector enrichment
5. Prometheus scrape / target metadata

## 阅读顺序

| 你要解决的问题 | 先看哪里 |
|---|---|
| HTTP access log 应该带哪些字段 | [HTTP 信号映射](http/) |
| 哪些 metric labels 是必须的 | [Metrics 规范](metrics/) |
| 哪些日志字段必须带 trace 关联键 | [Logs 规范](logs/) |
| 哪些 trace 字段属于 root span、resource 和 Collector enrichment | [Traces 规范](traces/) |

## 文档列表

- [HTTP 信号映射](http/)
- [Metrics 规范](metrics/)
- [Logs 规范](logs/)
- [Traces 规范](traces/)
```

- [ ] **Step 2: Add subtree entry into the main observability index**

Update `content/docs/observability/_index.md` by adding a new section before `## 全部文档`:

```md
## Signal 分层规范

这组文档面向运维和平台开发，重点回答“字段该放在哪种 signal、由谁负责写、哪些是必须、哪些是禁止项”。

| 文档 | 单一职责 |
|------|----------|
| [Signal 分层规范](signals/) | 新目录入口，解释责任边界和阅读顺序 |
| [HTTP 信号映射](signals/http/) | 定义 HTTP access log、HTTP metrics、HTTP traces 的字段映射 |
| [Metrics 规范](signals/metrics/) | 定义指标 labels 的必须项、可选项、平台注入项和禁止项 |
| [Logs 规范](signals/logs/) | 定义 HTTP access、HTTP error、业务和生命周期日志字段 |
| [Traces 规范](signals/traces/) | 定义 root span、child span、resource attributes 和 Collector enrichment |
```

- [ ] **Step 3: Run a focused content check**

Run: `sed -n '1,240p' content/docs/observability/signals/_index.md && sed -n '1,260p' content/docs/observability/_index.md`

Expected:
- New `signals/` index exists
- Main observability index contains the new signal section
- Terminology uses target-state and ownership wording consistently

### Task 2: Write HTTP Mapping Page

**Files:**
- Create: `content/docs/observability/signals/http.md`
- Reference: `content/docs/observability/contracts/logging.md`
- Reference: `content/docs/observability/contracts/standard.md`

- [ ] **Step 1: Write the HTTP mapping page with field-level access log detail**

Write `content/docs/observability/signals/http.md` with these sections and tables:

```md
---
title: "HTTP 信号映射"
weight: 82
---

# HTTP 信号映射

这页定义同一个 HTTP 请求在 metrics、logs、traces 三种 signal 里的目标形态字段映射。

## HTTP access log 必需字段

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `timestamp` | 必须 | 框架 / logger encoder | 事件时间 |
| `severity_text` | 必须 | logger | 正常请求通常为 `INFO` |
| `message` | 必须 | middleware | 固定请求完成消息 |
| `logger.name` | 必须 | middleware | 固定为 `http.access` |
| `caller` | 必须 | logger | 调试定位字段 |
| `trace_id` | 必须 | SDK / current span context | Trace 关联键 |
| `span_id` | 必须 | SDK / current span context | Span 关联键 |
| `http.request.method` | 必须 | HTTP middleware | 请求方法 |
| `http.route` | 必须 | HTTP middleware | 路由模板，不是原始路径 |
| `url.path` | 必须 | HTTP middleware | 原始请求路径，只适合 log / trace |
| `http.response.status_code` | 必须 | HTTP middleware | 响应状态码 |

## HTTP access log 可选字段

| 字段 | 是否推荐 | 来源 | 说明 |
|---|---|---|---|
| `http.request.body.size` | 可选 | middleware | 请求体大小可知且有意义时 |
| `http.response.body.size` | 推荐 | middleware | 普通 access log 推荐保留 |
| `user_agent.original` | 可选 | middleware | 平台需要 UA 分析时 |
| `duration_ms` | 可选 | middleware | 如保留则只进日志，不进 Loki label |

## HTTP access log 不应默认重复的字段

- `service.name`
- `service.namespace`
- `service.version`
- `deployment.environment.name`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`
- 请求级 `devflow.*.id`

## HTTP error log 追加字段

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `logger.name=http.error` | 必须 | middleware | 错误请求分类 |
| `message` | 必须 | middleware / service | 错误文本或 panic 文本 |
| `result=error` | 推荐 | service / middleware | 错误语义归类 |
| `error.type` | 可选 | service | 需要稳定错误分类时 |

## HTTP metrics 必需 labels

| label | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `http_request_method` | 必须 | framework metrics instrumentation | 低基数 |
| `http_route` | 必须 | framework metrics instrumentation | 路由模板 |
| `http_response_status_code` | 必须 | framework metrics instrumentation | 原始状态码 |

## HTTP metrics 可选 labels

| label | 是否允许 | 来源 | 说明 |
|---|---|---|---|
| `result` | 可选 | service or middleware | 仅低基数场景 |
| `action` | 可选 | service | 仅业务指标，不是默认 HTTP 基线 |

## HTTP metrics 禁止 labels

- `trace_id`
- `span_id`
- `url.path`
- `release_id`
- `manifest_id`
- `request_id`
- `user_id`
- `client.address`
- 自由文本错误

## HTTP trace / span 必需 attributes

| attribute | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `trace_id` | 必须 | SDK | Trace 主键 |
| `span_id` | 必须 | SDK | Span 主键 |
| `span.kind=server` | 必须 | HTTP instrumentation | 服务端入口 |
| `service.name` | 必须 | resource | 服务身份 |
| `http.request.method` | 必须 | HTTP instrumentation | 请求方法 |
| `http.route` | 必须 | HTTP instrumentation | 路由模板 |
| `http.response.status_code` | 必须 | HTTP instrumentation | 状态码 |
| `url.path` | 推荐 | HTTP instrumentation | 原始路径，适合 trace/log |

## 同一字段在三种 signal 的归属

| 语义 | Metrics | Logs | Traces |
|---|---|---|---|
| 请求方法 | `http_request_method` | `http.request.method` | `http.request.method` |
| 路由模板 | `http_route` | `http.route` | `http.route` |
| 状态码 | `http_response_status_code` | `http.response.status_code` | `http.response.status_code` |
| 原始路径 | 禁止 | `url.path` | `url.path` |
| Trace 关联键 | exemplar only | `trace_id` / `span_id` | `trace_id` / `span_id` |

## 反模式

- 把 `trace_id` 放进 HTTP metrics label
- 把 `url.path` 放进高频 HTTP metrics label
- 在每条 access log 里手工重复 `k8s.*` 和 `service.*`
- access log 没有 `trace_id` / `span_id`
```

- [ ] **Step 2: Verify the HTTP page covers access log detail**

Run: `rg -n "HTTP access log|http.access|http_request_method|trace_id|url.path" content/docs/observability/signals/http.md`

Expected:
- The page explicitly covers HTTP access logs
- Required and optional fields are both present
- Metrics, logs, and traces are mapped using the same request concepts

### Task 3: Write Metrics Specification Page

**Files:**
- Create: `content/docs/observability/signals/metrics.md`
- Reference: `content/docs/observability/contracts/standard.md`

- [ ] **Step 1: Write the metrics specification page**

Write `content/docs/observability/signals/metrics.md` with:

```md
---
title: "Metrics 规范"
weight: 83
---

# Metrics 规范

这页定义 DevFlow 目标形态的 metrics labels、来源边界和禁止项。

## 必须 labels

| label | 是否必须 | 来源 | 适用面 | 说明 |
|---|---|---|---|---|
| `http_request_method` | 必须 | framework instrumentation | HTTP server metrics | 路由请求方法 |
| `http_route` | 必须 | framework instrumentation | HTTP server metrics | 路由模板 |
| `http_response_status_code` | 必须 | framework instrumentation | HTTP server metrics | 状态码 |

## 可选 labels

| label | 是否允许 | 来源 | 适用面 | 说明 |
|---|---|---|---|---|
| `result` | 可选 | service | 低基数业务指标 | `success` / `error` |
| `action` | 可选 | service | 低基数业务指标 | `sync` / `render` |
| `strategy` | 可选 | service | 发布相关业务指标 | `canary` / `blue-green` |
| `task_name` | 可选 | service | 异步任务指标 | 有限集合 |

## 身份字段的目标归属

| 字段 | 目标归属 | 说明 |
|---|---|---|
| `service_name` | Prometheus target metadata / resource mapping | 不默认做每条 HTTP 指标 label |
| `service_namespace` | Prometheus target metadata / resource mapping | 平台统一提供 |
| `deployment_environment_name` | Prometheus target metadata / resource mapping | 平台统一提供 |
| `service_version` | 低频聚合需要时可显式使用 | 非默认高频 label |

## Prometheus / OTel 平台注入项

| 项目 | 来源 | 说明 |
|---|---|---|
| target identity | Prometheus scrape labels | 服务和命名空间身份 |
| trace-derived metrics | OTel Collector spanmetrics | 只能补充，不替代原生 metrics |
| exemplar trace jump | Prometheus + trace backend integration | 通过 exemplar 跳 Trace，不靠 `trace_id` label |

## 禁止 labels

- `trace_id`
- `span_id`
- `request_id`
- `url.path`
- `client.address`
- `devflow.release.id`
- `devflow.manifest.id`
- `error.message`
- 任意自由文本

## 验收清单

- HTTP metrics 只保留低基数 labels
- 原始路径不进入 label
- trace 关联通过 exemplar，不通过 `trace_id` label
- 服务身份优先来自平台元数据，不在每条 HTTP 指标上重复
```

- [ ] **Step 2: Verify the metrics page enforces cardinality boundaries**

Run: `rg -n "禁止 labels|trace_id|url.path|Prometheus|spanmetrics" content/docs/observability/signals/metrics.md`

Expected:
- The page clearly distinguishes required, optional, and forbidden labels
- Platform ownership for identity fields is explicit

### Task 4: Write Logs Specification Page

**Files:**
- Create: `content/docs/observability/signals/logs.md`
- Reference: `content/docs/observability/contracts/logging.md`

- [ ] **Step 1: Write the logs specification page with category-level detail**

Write `content/docs/observability/signals/logs.md` with:

```md
---
title: "Logs 规范"
weight: 84
---

# Logs 规范

这页定义 DevFlow 目标形态的日志字段、日志分类、归属边界和 Loki label 限制。

## 共享基础字段

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `timestamp` | 必须 | logger encoder | 事件时间 |
| `severity_text` | 必须 | logger | 级别 |
| `message` | 必须 | middleware / service | 人可读文本 |
| `logger.name` | 必须 | middleware / service | 日志分类主键 |
| `caller` | 必须 | logger | 调试定位字段 |
| `trace_id` | 必须 | current span context | Trace 关联键 |
| `span_id` | 必须 | current span context | Span 关联键 |

## HTTP access logs

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `timestamp` | 必须 | logger encoder | 事件时间 |
| `severity_text` | 必须 | logger | 正常请求通常为 `INFO` |
| `message` | 必须 | middleware | 固定请求完成消息 |
| `logger.name=http.access` | 必须 | middleware | access log 分类 |
| `caller` | 必须 | logger | 调试定位字段 |
| `trace_id` | 必须 | current span context | Trace 关联键 |
| `span_id` | 必须 | current span context | Span 关联键 |
| `http.request.method` | 必须 | middleware | 请求方法 |
| `http.route` | 必须 | middleware | 路由模板 |
| `url.path` | 必须 | middleware | 原始请求路径 |
| `http.response.status_code` | 必须 | middleware | 状态码 |
| `http.request.body.size` | 可选 | middleware | 请求体大小可知且有意义时 |
| `http.response.body.size` | 推荐 | middleware | 普通 access log 推荐保留 |

明确不应默认重复这些字段：

- `service.name`
- `service.namespace`
- `service.version`
- `deployment.environment.name`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`
- 高频 access log 场景中的请求级 `devflow.*.id`

## HTTP error logs

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `timestamp` | 必须 | logger encoder | 事件时间 |
| `severity_text` | 必须 | logger | 4xx 通常为 `WARN`，5xx / panic 通常为 `ERROR` |
| `message` | 必须 | middleware / service | 错误文本或 panic 文本 |
| `logger.name=http.error` | 必须 | middleware | 错误请求分类 |
| `caller` | 必须 | logger | 调试定位字段 |
| `trace_id` | 必须 | current span context | Trace 关联键 |
| `span_id` | 必须 | current span context | Span 关联键 |
| `http.request.method` | 必须 | middleware | 请求方法 |
| `http.route` | 必须 | middleware | 路由模板 |
| `url.path` | 必须 | middleware | 原始请求路径 |
| `http.response.status_code` | 必须 | middleware | 状态码 |
| `result` | 推荐 | middleware / service | 推荐固定为 `error` |
| `error.type` | 可选 | service | 需要稳定错误分类时 |

## business event logs

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `operation` | 必须 | service | 动作名 |
| `resource` | 必须 | service | 资源类型 |
| `result` | 必须 | service | `success` / `error` |
| `devflow.application.id` | 推荐 | service | 业务对象 |

## lifecycle / mutation logs

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `operation` | 必须 | service | 如 `create_release` |
| `resource` | 必须 | service | 如 `release` |
| `result` | 必须 | service | 结果 |
| `devflow.release.id` | 推荐 | service | 发布定位主键 |
| `devflow.manifest.id` | 可选 | service | 构建快照定位 |

## 平台注入项

| 字段 | 来源 | 说明 |
|---|---|---|
| `k8s.cluster.name` | OTel Collector enrichment | 不要求服务手写 |
| `k8s.namespace.name` | OTel Collector enrichment | 不要求服务手写 |
| `k8s.pod.name` | OTel Collector enrichment | 不要求服务手写 |
| `service.name` | resource / pipeline metadata | 不要求每条普通请求日志重复 |

## 不应作为 Loki label 的字段

- `caller`
- `trace_id`
- `span_id`
- `url.path`
- `message`
- `devflow.release.id` 在高频 access log 场景中不做 stream label

## 反模式

- access log 没有 `trace_id` / `span_id`
- 用 `caller` 代替 `logger.name`
- 让每个服务自己手写 `k8s.pod.name`
- 为了查询方便把自由文本字段做成 Loki label
```

- [ ] **Step 2: Verify the logs page is detailed enough for operations readers**

Run: `rg -n "HTTP access logs|HTTP error logs|business event|Loki label|trace_id" content/docs/observability/signals/logs.md`

Expected:
- The page distinguishes log categories clearly
- HTTP access and HTTP error logs are both explicitly specified
- Platform-enriched versus service-written fields are separated

### Task 5: Write Traces Specification Page

**Files:**
- Create: `content/docs/observability/signals/traces.md`
- Reference: `content/docs/observability/contracts/standard.md`
- Reference: `content/docs/observability/release-trace-example.md`

- [ ] **Step 1: Write the traces specification page**

Write `content/docs/observability/signals/traces.md` with:

```md
---
title: "Traces 规范"
weight: 85
---

# Traces 规范

这页定义 DevFlow 目标形态的 span attributes、resource attributes、Collector enrichment 和发布链路特殊上下文。

## Root span 必需字段

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `trace_id` | 必须 | SDK | Trace 主键 |
| `span_id` | 必须 | SDK | Span 主键 |
| `span.kind` | 必须 | instrumentation | HTTP 入口通常为 `server` |
| `span.name` | 必须 | instrumentation | 稳定入口名 |
| `service.name` | 必须 | resource | 服务身份 |
| `http.request.method` | 必须 | instrumentation | HTTP 方法 |
| `http.route` | 必须 | instrumentation | 路由模板 |
| `http.response.status_code` | 必须 | instrumentation | 状态码 |

## Internal span 推荐字段

| 字段 | 是否推荐 | 来源 | 说明 |
|---|---|---|---|
| `devflow.application.id` | 推荐 | service | 业务定位 |
| `devflow.environment.id` | 推荐 | service | 环境定位 |
| `devflow.release.id` | 发布链路强烈推荐 | service | 发布定位 |
| `devflow.manifest.id` | 发布链路推荐 | service | 构建快照定位 |

## Downstream client span

| 字段 / 规则 | 是否要求 | 来源 | 说明 |
|---|---|---|---|
| `span.kind=client` | 必须 | instrumentation | 对外依赖调用必须有 client span |
| `span.name` | 必须 | instrumentation / service | 用稳定依赖动作名，例如 `argocd.CreateApplication` |
| `server.address` 或等价对端地址 | 推荐 | instrumentation | 依赖落点定位 |
| `http.request.method` | HTTP 调用时推荐 | instrumentation | 下游 HTTP 请求方法 |
| `http.response.status_code` | HTTP 调用时推荐 | instrumentation | 下游响应状态码 |
| `error.message` | 失败时可选 | instrumentation / service | 失败细节 |

补充约束：

- 对外部 HTTP、Kubernetes、Tekton、Argo CD 调用必须有 client span
- client span 不替代内部阶段 span
- 既要看得见“调用了外部系统”，也要看得见“DevFlow 自己在哪个内部阶段发起了这次调用”

## Async / callback span

| 字段 / 规则 | 是否要求 | 来源 | 说明 |
|---|---|---|---|
| 稳定 `span.name` | 必须 | service | 如 `runtime-service.WatchReleaseStatus`、`runtime.WriteReleaseStatusBack` |
| `devflow.application.id` | 推荐 | service | 业务对象定位 |
| `devflow.environment.id` | 推荐 | service | 环境定位 |
| `devflow.release.id` | 发布链路强烈推荐 | service | 发布主定位键 |
| `devflow.intent.kind` | 异步执行推荐 | service | build / release / callback 等类型 |
| `devflow.intent.status` | 异步执行推荐 | service | running / failed / completed |

补充约束：

- 对 worker、回写、observer、runtime watch 场景，span 名必须稳定
- 需要保留可串联的 `devflow.*` 业务字段

## Resource attributes

| 字段 | 是否必须 | 来源 | 说明 |
|---|---|---|---|
| `service.name` | 必须 | resource | 服务名称 |
| `service.namespace` | 推荐 | resource | 服务命名空间 |
| `service.version` | 推荐 | resource | 服务版本 |
| `deployment.environment.name` | 必须 | resource / Collector | 部署环境 |

## Collector enrichment

| 字段 | 来源 | 说明 |
|---|---|---|
| `k8s.cluster.name` | Collector | 集群名称 |
| `k8s.namespace.name` | Collector | 命名空间 |
| `k8s.pod.name` | Collector | Pod 名 |
| `k8s.container.name` | Collector | 容器名 |

## 发布链路特殊字段

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.release.id`
- `devflow.manifest.id`
- `devflow.intent.kind`
- `devflow.intent.status`

## 反模式

- 只有外部依赖 span，没有 DevFlow 内部阶段 span
- root span 没有 `devflow.release.id`
- 让服务代码自己硬编码 `k8s.*`
```

- [ ] **Step 2: Verify the traces page aligns with the release trace guidance**

Run: `rg -n "Root span|Collector enrichment|devflow.release.id|internal stage span" content/docs/observability/signals/traces.md`

Expected:
- The page covers root span, internal span, client span, resource, and Collector enrichment
- Release-specific context fields are listed explicitly

### Task 6: Final Review And Build Validation

**Files:**
- Review: `content/docs/observability/signals/_index.md`
- Review: `content/docs/observability/signals/http.md`
- Review: `content/docs/observability/signals/metrics.md`
- Review: `content/docs/observability/signals/logs.md`
- Review: `content/docs/observability/signals/traces.md`
- Review: `content/docs/observability/_index.md`

- [ ] **Step 1: Run a placeholder and terminology scan**

Run: `rg -n "TODO|TBD|占位|待补|稍后" content/docs/observability/signals content/docs/observability/_index.md`

Expected:
- No placeholder text found

- [ ] **Step 2: Run Hugo build validation**

Run: `hugo --minify`

Expected:
- Build succeeds
- Existing site-level layout warnings may remain, but there are no new content parsing failures

- [ ] **Step 3: Review final changed files**

Run: `git diff -- content/docs/observability/_index.md content/docs/observability/signals`

Expected:
- Diff only contains the new subtree and the intended observability index link additions
