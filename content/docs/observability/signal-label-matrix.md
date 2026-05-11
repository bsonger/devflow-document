---
title: "信号标签矩阵"
weight: 74
---

# 信号标签矩阵

<span class="df-badge">Metrics</span> <span class="df-badge">Traces</span> <span class="df-badge">Logs</span> <span class="df-badge">Label Matrix</span>

这页回答两个问题：

1. **Metrics / Traces / Logs 各自最少需要哪些标签？**
2. **这些标签应该由服务代码、服务配置，还是平台统一注入？**

读完后，你应该能完成一件事：

> 判断一个标签应该进哪种信号，以及它应该放在哪一层维护。

如果你需要完整字段契约或详细示例，不要停在这页：

- 完整字段定义看 [信号字段契约](../standard/)
- 字段命名和来源边界看 [字段命名与来源边界](../attributes/)
- 日志分类和 `logger.name` / `caller` 细节看 [结构化日志规范](../logging/)

---

## 先记总原则

三种信号的职责不同：

- **Metrics**：看趋势、做聚合，最怕高基数
- **Traces**：看链路、看阶段，最适合带业务对象 ID
- **Logs**：看细节、看错误文本，最适合补充事件上下文

所以三者不应该机械地带完全一样的标签。

---

## 1. 先看统一基线

如果只想回答“**三种信号各自必须带什么标签**”，先看这张表：

| 信号 | 必需标签 |
|------|----------|
| Metrics | `service_name`、`http_request_method`、`http_route`、`http_response_status_code`、`http_response_status_class` |
| Traces | `service.name`、`service.namespace`、`trace_id`、`span_id`、`span.name`、`span.kind`、`http.request.method`、`http.route`、`http.response.status_code` |
| Logs | `timestamp`、`severity_text`、`logger.name`、`message`、`caller`、`trace_id`、`span_id` |

补充约束：

- Metrics 里的 `trace_id` / `span_id` 仍然**禁止**作为 label，只能通过 exemplar 关联
- Logs 里的 `trace_id` / `span_id` 是 Trace -> Log 关联主键，不再只是“推荐有”
- `http_response_status_class` 是 DevFlow HTTP metrics 查询和仪表盘的必需维度，不应再视为可有可无

---

## 2. Metrics 最少需要什么标签

### 必备

- `service_name`
- `http_request_method`
- `http_route`
- `http_response_status_code`
- `http_response_status_class`

### 强烈建议

- `service_version`
- `service_namespace`
- `result`（仅低基数工作流/依赖类指标）
- `action`（仅低基数场景）

### 不建议放进 Metrics labels

- `devflow.release.id`
- `devflow.manifest.id`
- `devflow.application.id`
- `devflow.environment.id`
- `request_id`
- `user_id`
- `trace_id`
- `span_id`
- 原始 URL / query string
- `error.message`

### Metrics 的核心目标

Metrics 应该优先回答：

- 哪个服务慢
- 哪条路由慢
- 哪个状态码段异常
- 哪个依赖变慢

而不是回答“哪一次具体发布失败了”。

---

## 3. Traces 最少需要什么标签

### 必备

- `service.name`
- `service.namespace`
- `trace_id`
- `span_id`
- `span.name`
- `span.kind`
- `http.request.method`
- `http.route`
- `http.response.status_code`

### 强烈建议

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.manifest.id`
- `devflow.release.id`
- `devflow.intent.kind`
- `devflow.intent.status`
- `error.type`
- `error.message`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`

### Traces 的核心目标

Trace 应该优先回答：

- 这条请求/发布链路经过了哪些阶段
- 卡在哪个下游
- 是哪次发布
- 哪个 Span 失败了

所以 `devflow.release.id` 这类上下文最适合在 Trace 中完整保留。

---

## 4. Logs 最少需要什么标签

### 必备

- `timestamp`
- `severity_text`
- `message`
- `logger.name`
- `caller`
- `trace_id`
- `span_id`

### 强烈建议

- 业务变更日志上的 `operation`
- 业务变更日志上的 `resource`
- 业务变更日志上的 `result`
- mutation / lifecycle 日志上的稳定 `devflow.*.id`

### Logs 的核心目标

Log 应该优先回答：

- 具体发生了什么
- 影响的是哪个业务对象
- 错误原因是什么
- 这个事件在业务上意味着什么

---

## 最终标签归属矩阵

| 标签 | Metrics | Traces | Logs | 推荐归属 |
|------|---------|--------|------|----------|
| `service_name` / `service.name` | ✅ 必备 | ✅ 必备 | ◑ 推荐来自 Resource | 服务配置 / Resource |
| `service_version` / `service.version` | ◑ 建议 | ✅ 建议 | ◑ 可有 | 服务配置 / Resource |
| `deployment_environment_name` / `deployment.environment.name` | ◑ 可选 | ✅ 建议 | ◑ 可有 | Resource / Collector |
| `http_response_status_class` | ✅ 必备 | ❌ | ❌ | 服务代码 / HTTP instrumentation |
| `k8s_cluster_name` / `k8s.cluster.name` | ❌ | ✅ 建议 | ◑ 可有 | OTel Collector |
| `k8s_namespace_name` / `k8s.namespace.name` | ❌ | ✅ 建议 | ◑ 可有 | OTel Collector |
| `k8s_pod_name` / `k8s.pod.name` | ❌ | ✅ 建议 | ◑ 可有 | OTel Collector |
| `devflow.project.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.application.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.environment.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.manifest.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.release.id` | ❌ | ✅ 强烈建议 | ✅ 强烈建议 | 服务代码 |
| `devflow.intent.kind` | ◑ 低基数时可用 | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.intent.status` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `trace_id` | ◑ exemplar 场景 | ✅ 必备 | ✅ 必备 | 自动生成 / SDK |
| `span_id` | ❌ | ✅ 必备 | ✅ 必备 | 自动生成 / SDK |
| `error.type` | ❌ | ✅ 建议 | ◑ 按需 | 服务代码 |
| `error.message` | ❌ | ✅ 建议 | 建议收敛进 `message` | 服务代码 |
| `caller` | ❌ | ❌ | ✅ 可有 | logger encoder |

说明：

- `✅ 必备` = 没有它，这种信号的排障价值会明显下降
- `✅ 建议` = 很推荐，但可按场景渐进补齐
- `❌` = 不建议放进该类信号
- `◑` = 有条件使用，需看基数、价值和成本

---

## 5. 一个实用决策规则

看到一个新标签时，依次问：

1. **多个服务是否都要带它？**
2. **它的 key 和 value 是否在平台层都稳定一致？**
3. **平台是否能 100% 正确给出它？**
4. **它是不是业务语义，而不是环境语义？**

### 如果答案是：

- **多服务共用 + 平台能稳定给出 + 非业务语义**
  - 优先放 **OTel Collector / Resource Attributes**

- **只有业务逻辑自己知道 / value 随请求变化**
  - 放 **服务代码**

- **服务身份、版本这类进程级稳定属性**
  - 放 **服务配置 / OTEL Resource Attributes**

---

## 6. 当前最值得统一的标签边界

建议平台优先统一注入：

- `deployment.environment.name`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`
- `k8s.node.name`
- `cloud.region`

建议服务统一在代码里补齐：

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.manifest.id`
- `devflow.release.id`
- `operation`
- `resource`
- `result`

建议优先通过当前 span context 自动注入：

- `trace_id`
- `span_id`

---

## 关联阅读

- [字段命名与来源边界](../attributes/)
- [信号字段契约](../standard/)
- [结构化日志规范](../logging/)
- [OTel 接入检查清单](../onboarding-checklist/)
