---
title: "信号标签矩阵"
weight: 74
---

# 🧩 Metrics / Traces / Logs 标签矩阵

<span class="df-badge">Metrics</span> <span class="df-badge">Traces</span> <span class="df-badge">Logs</span> <span class="df-badge">Label Matrix</span>

这页回答两个问题：

1. **Metrics / Traces / Logs 各自最少需要哪些标签？**
2. **这些标签应该由服务代码、服务配置，还是平台统一注入？**

读完后，你应该能完成一件事：

> **判断一个标签应该进哪种信号，以及它应该放在哪一层维护。**

---

## 🧭 先记总原则

三种信号的职责不同：

- **Metrics**：看趋势、做聚合，最怕高基数
- **Traces**：看链路、看阶段，最适合带业务对象 ID
- **Logs**：看细节、看错误，最适合补充上下文

所以三者不应该机械地带完全一样的标签。

---

## ① Metrics 最少需要什么标签

### 必备

- `service.name`
- `deployment.environment`
- `http.method`
- `http.route`
- `http.status_code`
- `k8s.cluster.name`

### 强烈建议

- `service.version`
- `k8s.namespace.name`
- `k8s.pod.name`（确实需要 Pod 级分析时）
- `devflow.intent.kind`（仅低基数任务类型）

### 不建议放进 Metrics labels

- `devflow.release.id`
- `devflow.manifest.id`
- `devflow.application.id`（通常也不建议）
- `request_id`
- `user_id`
- 原始 URL / query string
- `error.message`

### Metrics 的核心目标

Metrics 应该优先回答：

- 哪个服务慢
- 哪条路由慢
- 哪个环境错误率高
- 哪个集群/命名空间出现异常

而不是回答“哪一次具体发布失败了”。

---

## ② Traces 最少需要什么标签

### 必备

- `service.name`
- `deployment.environment`
- `trace_id`
- `span_id`
- `span.name`
- `span.kind`
- `http.method`
- `http.route`
- `http.status_code`

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

所以 `devflow.release.id` 这类字段最适合在 Trace 中完整保留。

---

## ③ Logs 最少需要什么标签

### 必备

- `timestamp`
- `log.level`
- `log.message`
- `service.name`
- `deployment.environment`

### 强烈建议

- `trace_id`
- `span_id`
- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.manifest.id`
- `devflow.release.id`
- `error.type`
- `error.message`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`

### Logs 的核心目标

Log 应该优先回答：

- 具体发生了什么
- 影响的是哪个业务对象
- 错误原因是什么
- 是哪个 Pod 打出来的

---

## 🗂️ 最终标签归属矩阵

| 标签 | Metrics | Traces | Logs | 推荐归属 |
|------|---------|--------|------|----------|
| `service.name` | ✅ 必备 | ✅ 必备 | ✅ 必备 | 服务配置 |
| `service.version` | ◑ 建议 | ◑ 建议 | ◑ 建议 | 服务配置 |
| `deployment.environment` | ✅ 必备 | ✅ 必备 | ✅ 必备 | OTel / 平台统一注入优先 |
| `k8s.cluster.name` | ✅ 必备 | ✅ 必备 | ◑ 建议 | OTel Collector |
| `k8s.namespace.name` | ◑ 建议 | ✅ 建议 | ✅ 建议 | OTel Collector |
| `k8s.pod.name` | ◑ 建议 | ✅ 建议 | ✅ 建议 | OTel Collector |
| `devflow.project.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.application.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.environment.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.manifest.id` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.release.id` | ❌ | ✅ 强烈建议 | ✅ 强烈建议 | 服务代码 |
| `devflow.intent.kind` | ◑ 低基数时可用 | ✅ 建议 | ✅ 建议 | 服务代码 |
| `devflow.intent.status` | ❌ | ✅ 建议 | ✅ 建议 | 服务代码 |
| `trace_id` | ◑ exemplar 场景 | ✅ 必备 | ✅ 强烈建议 | 自动生成 / 服务代码 |
| `span_id` | ❌ | ✅ 必备 | ✅ 建议 | 自动生成 / 服务代码 |
| `error.type` | ❌ | ✅ 建议 | ✅ 强烈建议 | 服务代码 |
| `error.message` | ❌ | ✅ 建议 | ✅ 强烈建议 | 服务代码 |

说明：

- `✅ 必备` = 没有它，这种信号的排障价值会明显下降
- `✅ 建议` = 很推荐，但可按场景渐进补齐
- `❌` = 不建议放进该类信号
- `◑` = 有条件使用，需看基数和成本

---

## 🧠 一个实用决策规则

看到一个新标签时，依次问：

1. **多个服务是否都要带它？**
2. **它的 key 和 value 是否在平台层都稳定一致？**
3. **平台是否能 100% 正确给出它？**
4. **它是不是业务语义，而不是环境语义？**

### 如果答案是：

- **多服务共用 + value 一样 + 平台能稳定给出 + 非业务语义**
  - → 优先放 **OTel Collector / 平台统一注入**

- **只有业务逻辑自己知道 / value 随请求变化**
  - → 放 **服务代码**

- **服务身份、版本这类进程级稳定属性**
  - → 放 **服务配置**

---

## ✅ 你们当前最值得统一的标签

建议平台优先统一注入：

- `deployment.environment`
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
- `error.type`
- `error.message`

---

## 关联阅读

- [公共 Attributes](../attributes/)
- [Labels / Attributes 规范](../standard/)
- [结构化日志规范](../logging/)
- [OTel 接入检查清单](../onboarding-checklist/)
