---
title: "OTel 接入检查清单"
weight: 77
---

# ✅ OTel 接入检查清单

<span class="df-badge">Onboarding</span> <span class="df-badge">Metrics</span> <span class="df-badge">Logs</span> <span class="df-badge">Traces</span>

这页给的是一份**新服务接入 observability 时可直接照着走的检查清单**。

适合的读者：

- 正在新接一个 DevFlow 服务的开发者
- 想补齐已有服务 observability 的维护者
- 负责提供统一模板的平台工程师

读完之后，你应该能完成一件事：

> **判断一个服务是否已经具备“最小可排障”的 Metrics / Logs / Traces 能力。**

---

## 🧭 先看完成标准

只要下面 4 组都具备，这个服务就算“最小可用”：

| 维度 | 必须具备 |
|------|----------|
| 启动配置 | `service.name` `service.version` |
| Trace 基础链路 | `trace_id` `span_id` `http.request.method` `http.route` |
| 业务上下文 | `devflow.application.id`，发布链路再加 `devflow.release.id` |
| 平台公共元数据 | `deployment.environment.name` `k8s.cluster.name` `k8s.namespace.name` `k8s.pod.name` |

如果缺少其中任何一组，排障链路都会断。

---

## ① 启动配置检查

### 必查项

- [ ] 服务配置了 `SERVICE_NAME`
- [ ] 服务配置了 `OTEL_SERVICE_NAMESPACE`
- [ ] 服务配置了 `SERVICE_VERSION`
- [ ] 服务配置了 `OTEL_EXPORTER_OTLP_ENDPOINT`

### 通过标准

你应该能明确回答：

- 这个 telemetry 属于哪个服务？
- 当前运行的是哪个版本？
- 它跑在哪个环境？这个环境字段优先来自 Resource / Collector，而不是请求日志手工重复。

### 常见错误

- 把 `devflow.release.id` 塞进 `OTEL_RESOURCE_ATTRIBUTES`
- 漏掉 `service.name`
- 把本应平台统一注入的 `deployment.environment.name` 分散到每个服务手工维护

---

## ② Trace 基础链路检查

### 必查项

- [ ] HTTP 框架已经接入 OTel middleware
- [ ] 入口请求能自动生成 `trace_id`
- [ ] Span 中能看到 `http.request.method`
- [ ] Span 中能看到 `http.route`
- [ ] Span 中能看到 `http.response.status_code`

### 通过标准

随便请求一个 API，你至少能在 Trace 后端里看到：

- 一个入口 Span
- 正确的路由模板
- 正确的状态码

### 常见错误

- 只初始化 exporter，没有给 Web 框架挂 middleware
- 打的是原始 URL，不是路由模板
- Trace 有数据，但不同服务之间上下文没有传播

---

## ③ 业务字段检查

### 所有服务至少要有

- [ ] `devflow.application.id`

### 发布链路建议补齐

- [ ] `devflow.project.id`
- [ ] `devflow.environment.id`
- [ ] `devflow.manifest.id`
- [ ] `devflow.release.id`
- [ ] `devflow.intent.kind`
- [ ] `devflow.intent.status`

### 通过标准

看到一条 Trace 或 Log 时，你应该不只知道“哪个服务报错了”，还应该知道：

- 是哪个应用
- 是哪个环境
- 是不是某次具体发布

### 常见错误

- 只有 `trace_id`，没有 `devflow.*`
- 日志写 `releaseId`，Trace 写 `devflow.release.id`
- 所有业务字段都只打在 DEBUG 日志里

---

## ④ 日志检查

### 必查项

- [ ] 日志是结构化的
- [ ] 每条关键日志有 `severity_text`
- [ ] 每条关键日志有 `message`
- [ ] 每条关键日志有 `logger.name`
- [ ] 每条关键日志有 `caller`
- [ ] 关键日志能带 `trace_id`
- [ ] 关键日志能带 `span_id`

### 推荐补充

- [ ] `devflow.application.id`
- [ ] `devflow.release.id`
- [ ] `operation` / `resource` / `result`（适用于业务 / lifecycle 日志）

### 通过标准

你应该可以从某条 Trace 找到对应日志，也可以从某条错误日志反查对应 Trace。

---

## ⑤ Metrics 检查

### 必查项

- [ ] 有 HTTP 请求数 / 延迟 / 错误率类指标
- [ ] Metrics labels 至少包含 `service_name`
- [ ] HTTP 指标至少包含 `http_request_method` `http_route` `http_response_status_code`
- [ ] 没有明显高基数 labels

### 不该放进 Metrics labels 的字段

- [ ] `user_id`
- [ ] `request_id`
- [ ] `trace_id`
- [ ] `span_id`
- [ ] `release_id`
- [ ] 自由文本错误
- [ ] 原始 query string

### 通过标准

Prometheus / Grafana 中应该能按：

- 服务
- 路由
- 状态码

做聚合，而不会因为 label 爆炸变得不可用。

---

## ⑥ Collector 注入检查

### 必查项

- [ ] Collector 已启用 `k8sattributes`
- [ ] Collector 已补齐 `k8s.cluster.name`
- [ ] Trace 中能看到 `k8s.namespace.name`
- [ ] Trace / Log 中能看到 `k8s.pod.name`

### 通过标准

看到异常时，你应该能进一步定位到：

- 哪个 namespace
- 哪个 pod
- 哪个 cluster

### 常见错误

- 服务代码里自己手写 `k8s.pod.name`
- Collector 里尝试推断 `devflow.release.id`
- 只给 traces 补标签，logs 没补

---

## ⑦ 发布链路专项检查

如果这个服务直接参与发布流程，再额外检查：

- [ ] 创建 / 查询 Release 时带 `devflow.release.id`
- [ ] 创建 / 查询 Manifest 时带 `devflow.manifest.id`
- [ ] 异步任务有 `devflow.intent.kind`
- [ ] 异步任务有 `devflow.intent.status`
- [ ] 对 Tekton / Argo CD / runtime 的关键调用能串到同一条 Trace

对 release-service 来说，这一组通常是最重要的。

---

## 🧪 最小验收动作

接入完成后，至少做一次最小验收：

1. 调一个真实 API
2. 在 Trace 后端确认能看到入口 Span
3. 在 Span 中确认：
   - `service.name`
   - `devflow.application.id`
4. 确认 `deployment.environment.name`、`k8s.*` 由 Resource / Collector 负责，而不是请求日志手工重复
5. 在日志系统确认同一次请求能按 `trace_id` 查到日志
6. 在指标系统确认该路由有延迟 / 请求数 / 错误率指标

如果这 6 步都通过，说明基础链路已经打通。

---

## 🚫 一眼判断“还没接好”的信号

如果你看到下面这些现象，通常说明服务还没真正接好：

- 只有 Metrics，没有 Trace
- 只有 Trace，没有 `devflow.*`
- 日志很多，但没有 `trace_id`
- 看得到 Pod 级问题，但看不到业务对象
- 指标很多，但路由或状态码无法稳定聚合

---

## 关联阅读

- [公共 Attributes](../attributes/)
- [Labels / Attributes 规范](../standard/)
- [OTel Collector 配置模板](../collector/)
- [Go 服务最小 OTel 接入示例](../go-example/)
- [五大服务观测字段清单](../service-checklist/)
