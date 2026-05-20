---
title: "Signals 运维验收表"
weight: 77
---

# Signals 运维验收表

<span class="df-badge">Signals</span> <span class="df-badge">Validation</span> <span class="df-badge">Platform</span> <span class="df-badge">SRE</span>

这页不是“如何接入”的开发清单，而是一份给运维、平台、SRE 直接使用的 **signals target-state 验收表**。

它主要回答 4 个问题：

1. 当前服务或平台输出的 Metrics / Logs / Traces 是否符合统一规范
2. 哪些字段是框架写进去的，哪些字段必须由服务补，哪些字段应由 Resource / Collector / Prometheus 提供
3. 哪些标签必须存在，哪些只能按需出现，哪些必须禁止
4. 一次验收时应该先查什么，再查什么

如果你当前做的是：

- 新服务接入，请先看 [OTel 接入检查清单](../../observability/onboarding-checklist/)
- 按服务查漏补缺，请看 [现有服务字段清单](../../observability/service-checklist/)
- 统一字段命名和 canonical baseline，请回到 [字段契约](../../observability/contracts/)

这页只做一件事：

> 把 `signals/` 里的规范压缩成一张可以逐项打勾的运维验收表。

---

## 1. 验收使用方式

建议按下面顺序执行：

1. 先验 Metrics，确认聚合和告警面没有高基数问题
2. 再验 Traces，确认链路入口、阶段、下游依赖和业务身份完整
3. 最后验 Logs，确认单请求和单业务事件可以补足细节
4. 最后再验 owner，确认没有把服务字段、Collector 字段、Prometheus 字段写乱

执行原则：

- 先验“必需字段是否存在”
- 再验“可选字段是否有边界”
- 最后验“禁止字段是否被错误使用”

---

## 2. Metrics 验收表

### 2.1 必须通过

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| HTTP 高频指标存在 | 至少有 request rate / error rate / latency | 框架 / 指标 SDK |
| `http_request_method` | 必须存在 | 框架 / middleware 或指标 SDK |
| `http_route` | 必须存在，且是模板路由 | 框架 / middleware 或指标 SDK |
| `http_response_status_code` | 必须存在 | 框架 / middleware 或指标 SDK |
| 服务身份可切片 | 能按服务区分，但优先来自 Resource / scrape metadata，而不是应用侧重复 label | Resource / Prometheus |
| 环境身份可切片 | 能按环境区分，但优先来自 Resource / Collector / scrape metadata | Resource / Collector / Prometheus |
| exemplar 跳 Trace | 若平台启用 exemplar，应能从聚合点跳到 Trace | Metrics SDK / OTel pipeline |

### 2.2 允许但要受控

| 检查项 | 通过条件 | 默认 owner |
|--------|----------|------------|
| `service_name` | 仅在平台侧暂时不能稳定侧带时才作为应用 label | Resource |
| `service_namespace` | 同上 | Resource |
| `deployment_environment_name` | 仅在查询系统无法稳定侧带环境身份时显式加 label | Resource / Collector |
| `service_version` | 优先通过 `build_info` 类低频指标暴露；只有高频指标确有版本切片需求时才允许 | Resource |
| `result` | 仅低频业务指标允许，且值集合稳定 | 服务 |
| `action` | 仅动作集合有限时允许 | 服务 |
| `strategy` / `task_name` | 仅工作流或后台指标允许，且必须低基数 | 服务 |

### 2.3 必须判失败

| 检查项 | 为什么失败 | 更合适的位置 |
|--------|------------|--------------|
| `trace_id` 作为 label | 基数无限 | exemplar / Trace / Log |
| `span_id` 作为 label | 基数无限 | Trace / Log |
| `request_id` 作为 label | 高基数且常与 `trace_id` 重叠 | Log / Trace |
| `url.path` 作为 label | 原始路径基数不可控 | Log / Trace |
| `url.query` 作为 label | 高基数且可能含敏感数据 | Log |
| `error.message` 作为 label | 自由文本不可聚合 | Log `message` / Trace |
| `devflow.release.id` 作为高频指标 label | 业务对象 ID 高基数 | Trace / 业务日志 |
| `devflow.application.id` 作为高频指标 label | 同上 | Trace / 业务日志 |
| `k8s.pod.name` 作为默认高频切片 | Pod 滚动导致序列爆炸 | Resource / target metadata |

### 2.4 Metrics 一眼通过标准

- [ ] 高频 HTTP 指标只保留低基数标签
- [ ] `http_route` 是模板路由，不是原始动态路径
- [ ] 服务与环境身份可稳定切片，但没有长期双写同义 label
- [ ] `service.version` 如需进入 Metrics，优先通过 `build_info` 一类低频指标表达，而不是默认进入高频 HTTP 指标
- [ ] 请求主键、对象 ID、自由文本都没有进高频指标标签

---

## 3. Traces 验收表

### 3.1 必须通过

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| `trace_id` | 每条 Trace 必须存在 | SDK / 当前 span context |
| `span_id` | 每个 span 必须存在 | SDK / 当前 span context |
| `span.name` | 必须稳定，不带动态对象 ID | 框架 / middleware 或服务 |
| `span.kind` | 必须正确表达 `server` / `client` / `internal` / `consumer` 等语义 | SDK / instrumentation |
| `service.name` | 必须可见 | Resource |
| `service.namespace` | 必须可见 | Resource |
| 入口边界 span | HTTP / consumer / callback / job 入口必须存在 | 框架 / middleware / SDK / 服务 |
| 下游 client span | 外部依赖调用必须可见 | instrumentation / 服务 |
| 失败边界清晰 | 失败必须能落在具体失败 span 上 | 服务 |

### 3.2 发布链路必须额外检查

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| `devflow.release.id` | 发布关键阶段必须可见 | 服务 |
| `devflow.application.id` | 发布入口和关键阶段必须可见 | 服务 |
| `devflow.environment.id` | 部署与回写阶段必须可见 | 服务 |
| `devflow.manifest.id` | manifest / render / build 相关阶段必须可见 | 服务 |
| `devflow.intent.kind` | 异步或后台执行意图清晰 | 服务 |
| `runtime-service.WatchReleaseStatus` | runtime 观察边界可见 | 服务 |
| `release.CreateManifest` 等 canonical naming | span naming 与文档示例一致 | 服务 |

### 3.3 允许但要受控

| 检查项 | 通过条件 | 默认 owner |
|--------|----------|------------|
| `deployment.environment.name` | 作为 recommended trace-visible context 稳定可查 | Resource / Collector |
| `service.version` | 灰度、版本排障时应可见 | Resource |
| `service.instance.id` | 单实例排障时应可见 | Resource / SDK |
| `k8s.*` | 平台落点字段可查，但不由业务代码手写 | Collector |
| `error.type` / `error.message` | 仅失败 span 才出现 | 服务 |

### 3.4 必须判失败

| 检查项 | 为什么失败 |
|--------|------------|
| root span 带动态 ID 或原始 URL | span 名称高基数、不可聚合 |
| internal span 等于函数调用栈镜像 | 噪声过大，失去阶段语义 |
| 外部依赖失败只挂在父 span | 无法区分内部失败还是依赖失败 |
| `devflow.*.id` 被写入 Resource | 进程级污染业务对象身份 |
| Collector 猜 `devflow.release.id` | 平台越界且语义不稳定 |
| 大体积 payload / header / query 原文进入 span | 成本高且易泄漏敏感信息 |

### 3.5 Traces 一眼通过标准

- [ ] 任意请求都能看到明确入口 span
- [ ] 任意失败都能定位到具体失败边界 span
- [ ] 发布链路能按 `devflow.release.id` 串起关键阶段
- [ ] 运行落点与服务身份可查，但业务对象身份没有污染到 Resource

---

## 4. Logs 验收表

### 4.1 必须通过

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| `timestamp` | 必须存在 | 日志 SDK / encoder |
| `severity_text` | 必须存在 | 服务日志库 |
| `logger.name` | 必须存在，且使用稳定分类 | 服务 |
| `message` | 必须存在，且能直接表达事件含义 | 服务 |
| `caller` | 必须存在 | 日志 SDK / encoder |
| `trace_id` | 必须存在 | SDK / 当前 span context |
| `span_id` | 必须存在 | SDK / 当前 span context |

### 4.2 HTTP access / error log 专项

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| `http.request.method` | `http.access` 必须存在 | 框架 / middleware |
| `http.route` | `http.access` 必须存在，且为模板路由 | 框架 / middleware |
| `url.path` | `http.access` 必须存在，用于单请求排障 | 框架 / middleware |
| `http.response.status_code` | `http.access` 必须存在 | 框架 / middleware |
| `logger.name=http.access` | 普通入口访问日志固定分类 | 服务 |
| `logger.name=http.error` | 入口错误日志固定分类 | 服务 |
| `message` | `http.error` 必须能表达具体失败文本或 panic 摘要 | 服务 |
| `http.response.body.size` | 稳定可得时推荐保留 | 框架 / middleware |

### 4.3 业务 / 生命周期日志专项

| 检查项 | 验收标准 | 默认 owner |
|--------|----------|------------|
| `operation` | 业务动作明确 | 服务 |
| `resource` | 资源类型明确 | 服务 |
| `result` | 成功 / 失败 / 跳过等结果明确 | 服务 |
| `devflow.*.id` | 仅在确有业务语义的日志中出现 | 服务 |
| `release.lifecycle` / `runtime.state` 等稳定分类 | 日志分类统一 | 服务 |

### 4.4 必须判失败

| 检查项 | 为什么失败 | 更合适的位置 |
|--------|------------|--------------|
| `trace_id` 做 Loki label | label 爆炸 | JSON 字段 / Trace 关联 |
| `span_id` 做 Loki label | 同上 | JSON 字段 / Trace 关联 |
| `url.path` 做 Loki label | 高基数 | JSON 字段 |
| `message` 做 Loki label | 自由文本不可作为稳定流切分 | 日志正文 |
| 任意 `devflow.*.id` 做 Loki label | 业务对象 ID 高基数 | JSON 字段 / Trace |
| 每条 `http.access` 都手工重复 `service.*`、`k8s.*` | 高频日志被平台元数据淹没 | Resource / Collector |

### 4.5 Logs 一眼通过标准

- [ ] HTTP access log 只保留请求边界最小事实
- [ ] HTTP error log 能直接看懂失败原因
- [ ] 业务 / 生命周期日志能带稳定业务对象身份
- [ ] `trace_id` 能从日志反查 Trace，且没有被升级成 Loki label

---

## 5. Owner 验收表

### 5.1 框架 / middleware 应负责

- [ ] `http.request.method`
- [ ] `http.route`
- [ ] `url.path`
- [ ] `http.response.status_code`
- [ ] 基础请求耗时边界

### 5.2 服务代码应负责

- [ ] `devflow.project.id`
- [ ] `devflow.application.id`
- [ ] `devflow.environment.id`
- [ ] `devflow.manifest.id`
- [ ] `devflow.release.id`
- [ ] `devflow.intent.kind`
- [ ] `devflow.intent.status`
- [ ] `operation`
- [ ] `resource`
- [ ] `result`
- [ ] 业务错误语义和稳定 span naming

### 5.3 OTel SDK / Resource 应负责

- [ ] `trace_id`
- [ ] `span_id`
- [ ] `service.name`
- [ ] `service.namespace`
- [ ] `service.version`
- [ ] `service.instance.id`
- [ ] `build_info` 或等价版本常量指标

### 5.4 Collector 应负责

- [ ] `deployment.environment.name`
- [ ] `k8s.cluster.name`
- [ ] `k8s.namespace.name`
- [ ] `k8s.pod.name`
- [ ] `k8s.container.name`
- [ ] `k8s.node.name`
- [ ] `cloud.region`
- [ ] `host.name`

### 5.5 Prometheus 应负责

- [ ] `job`
- [ ] `instance`
- [ ] scrape target metadata

### 5.6 Owner 一眼失败信号

- [ ] Collector 在推断 `devflow.*`
- [ ] Prometheus label 在承载业务对象 ID
- [ ] 服务代码在手工双写 `k8s.*`、`cloud.*`
- [ ] 平台改写了服务已经确定的 `operation`、`resource`、`result`

---

## 6. 最小验收流程

建议值班或平台验收时至少跑完下面 8 步：

1. 选一个真实 HTTP 请求或一次真实发布动作
2. 在 Metrics 里确认请求量、时延、错误率存在
3. 确认高频指标只使用低基数标签
4. 从 exemplar 或时间点进入 Trace
5. 在 Trace 中确认入口 span、下游 span、失败边界和 `service.*`
6. 如果是发布链路，再确认 `devflow.release.id`、`devflow.application.id`、`devflow.environment.id`
7. 按 `trace_id` 反查日志，确认 `http.access`、`http.error` 或 lifecycle 日志可读
8. 最后确认 `k8s.*`、环境、实例等平台字段来自 Resource / Collector，而不是业务代码手工双写

如果这 8 步都通过，这套 signals 基本满足 DevFlow 当前 target-state 的运维验收要求。

---

## 7. 关联阅读

- [Signal 分层规范](../)
- [HTTP 字段边界](../http/)
- [Metrics 字段规范](../metrics/)
- [Logs 字段规范](../logs/)
- [Traces 字段规范](../traces/)
- [OTel 接入检查清单](../../observability/onboarding-checklist/)
- [现有服务字段清单](../../observability/service-checklist/)
