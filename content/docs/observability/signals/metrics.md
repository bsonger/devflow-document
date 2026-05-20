---
title: "Metrics 字段规范"
weight: 74
---

# Metrics 字段规范

<span class="df-badge">Metrics</span> <span class="df-badge">Prometheus</span> <span class="df-badge">OpenTelemetry</span> <span class="df-badge">SRE</span>

这页是 `contracts/` 通用字段契约在 **Metrics** 这一类信号上的目标态细化页。
它只回答运维、平台、SRE 在执行层真正要统一的几件事：

- 哪些指标标签是必需、可选、禁止
- 高频 HTTP 指标和低频业务/平台指标应如何分层
- 服务、OTel SDK、OTel Collector、Prometheus 各自负责什么
- 环境与服务身份字段应由哪一层提供，哪些不应复制进每条应用指标

这页不是实现教程，也不重写 `contracts/` 中的完整字段字典。
canonical naming 仍以 [字段命名与来源边界](../../observability/contracts/attributes/) 和 [信号字段契约](../../observability/contracts/standard/) 为准；这里负责把那套命名落实成 Metrics 的 target-state ownership 规则。

如果你当前关心的是 **HTTP request boundary** 上哪些字段该落到 Metrics / Logs / Traces、以及 HTTP 入口字段该由谁注入，优先看 [HTTP 字段边界](../http/)；这页只保留 Metrics 全局规则、label policy 和平台 ownership。

---

## 1. Metrics 的用途与分层

Metrics 只服务于四类问题：

- 趋势是否变坏
- 聚合后哪一类流量或任务在恶化
- 告警是否应触发
- SLO / 容量 / 错误预算是否被消耗

因此，Metrics 的 target state 必须先分层，而不是所有指标共用同一套标签策略。

| 指标层 | 典型对象 | 频率 | 标签策略 | 默认 owner |
|--------|----------|------|----------|------------|
| 高频 HTTP 指标 | request count / error / latency / size | 高 | 严格低基数，默认只保留请求聚合必需标签 | 框架、指标 SDK、Prometheus、Collector |
| 低频业务指标 | release、pipeline、callback、observer、task | 中低 | 允许有限业务维度，但必须是稳定、有限集合 | 服务 |
| 平台/运行时指标 | process、runtime、collector、自身导出器、平台组件 | 中低 | 以平台与运行时维度为主，不承载业务对象 ID | 平台、SDK、Collector、Prometheus |

默认规则：

- 高频 HTTP 指标优先保证可聚合、可查询、可告警，不为单请求排障服务
- 低频业务指标可以携带有限业务维度，但前提仍然是稳定、可枚举、可运维
- 平台/运行时指标不承载服务代码才知道的业务语义

---

## 2. 高频 HTTP 指标 required labels

高频 HTTP 指标默认是所有服务最容易爆序列数的区域，因此 required labels 必须收敛到最小集合。

| Label | 为什么必须有 | 默认 owner |
|-------|--------------|------------|
| `http_request_method` | 区分请求动作，支撑 rate / latency / error 的动作维度聚合 | 框架 / middleware 或指标 SDK |
| `http_route` | 稳定聚合到模板路由，而不是原始路径 | 框架 / middleware 或指标 SDK |
| `http_response_status_code` | 区分成功与失败，并支持查询层归并 `2xx` / `4xx` / `5xx` | 框架 / middleware 或指标 SDK |

约束：

- `http_route` 必须是模板路由，不允许是带动态 ID 的原始路径
- `http_response_status_code` 保留原始状态码值，不要求服务额外再打一层 `status_class`
- 这三个 label 构成 HTTP request rate / error / latency 的最小稳定切片
- 对同一类 HTTP 高频指标，不再默认追加服务、环境、Pod、实例类同义标签

---

## 3. 高频 HTTP 指标中的身份维度承载

`service_name`、`service_namespace`、`deployment_environment_name` 这类维度在整个 observability system level 仍然重要，而且通常是强需求；问题不在于“要不要有”，而在于**对高频 HTTP 指标，优先由哪一层承载**。

目标态规则：

- 这些身份维度应稳定存在于观测系统中
- 对高频 HTTP 指标，它们的首选载体是 Resource、OTel Collector enrichment 或 Prometheus target metadata
- 只有当平台侧暂时无法稳定提供同义元数据时，才允许应用侧把它们复制成 HTTP 指标 label
- `service.version` 更推荐通过 `build_info`、`version_info` 一类低频常量指标表达，而不是默认挂到高频 HTTP 指标

| 维度 | canonical attribute | Prometheus-safe label | 首选 owner | 高频 HTTP 指标中的默认承载方式 |
|------|---------------------|-----------------------|------------|------------------------------|
| 服务名 | `service.name` | `service_name` | Resource | 平台元数据，不是默认 app-side label |
| 服务命名空间 | `service.namespace` | `service_namespace` | Resource | 平台元数据，不是默认 app-side label |
| 部署环境 | `deployment.environment.name` | `deployment_environment_name` | Resource / Collector | 平台元数据，不是默认 app-side label |
| 服务版本 | `service.version` | `service_version` | Resource | 优先通过 `build_info` 一类低频指标或 Resource 暴露，不作为默认高频 HTTP label |
| 服务实例 | `service.instance.id` | `service_instance_id` | Resource | 不进入高频 HTTP 聚合标签 |

约束：

- 不把“平台侧应提供的身份维度”误写成“默认不重要”
- 不把“高频 HTTP 指标默认不复制这些 label”误解为“系统层不需要这些维度”
- 一旦平台侧已有稳定 carrier，应用侧同义 label 应删除而不是长期双写

### `service.version` 的 Metrics 推荐承载方式

`service.version` 对排障和灰度很有价值，但默认不应该进入每一条高频 HTTP 样本。

推荐做法：

| 载体 | 推荐形态 | 目的 |
|------|----------|------|
| Trace / Resource | `service.version` | 版本回溯、实例排障、灰度定位 |
| Metrics | `build_info{service_name,service_version,git_commit,build_date} 1` | 暴露版本事实，不打碎高频聚合 |
| 高频 HTTP 指标 | 默认不带 `service_version` | 保持请求指标聚合稳定 |

约束：

- `build_info` 必须是低频常量指标，不是按请求变化的业务指标
- `git_commit`、`build_date` 这类字段如果进入 `build_info`，也不应复制进高频 HTTP 指标
- 只有在确有版本切片需求、且平台侧不能稳定通过 Resource 或查询元数据拿到版本时，才临时考虑 `service_version` 进入高频指标

---

## 4. 低频业务指标允许的 labels

低频业务指标可以承载有限业务语义，但前提仍然是低基数、稳定、可枚举。

| Label | 何时允许使用 | 默认 owner |
|-------|--------------|------------|
| `result` | 指标不是通用 HTTP 指标，而是低频工作流/任务结果指标时 | 服务 |
| `action` | 动作集合稳定、有限且与原始路径无关时 | 服务 |
| `strategy` | 发布策略集合固定且确实需要用于低频聚合时 | 服务 |
| `pipeline_type` | 流水线类型集合固定时 | 服务 |
| `observer_type` | observer 分类集合固定时 | 服务 |
| `callback_type` | callback 分类集合固定时 | 服务 |
| `task_name` | 任务名集合已收敛为有限枚举时 | 服务 |

约束：

- 业务标签必须是有限集合，不是原始对象 ID
- 如果一个标签值集合无法在评审时明确上界，就不应进入指标
- 低频业务指标允许引入 `result`、`action`、`strategy`、`task_name` 等标签，但必须先证明能稳定支持 dashboard、告警或 SLO 切片

---

## 5. 高频 HTTP 指标与低频业务/平台指标的边界

这条边界是 target state 的核心，否则高频链路很快会被业务维度污染。

### 高频 HTTP 指标只保留请求事实

允许回答的问题：

- 哪条路由变慢了
- 哪种方法错误率升高了
- 哪类状态码在放大

不允许承载的内容：

- 单个用户、单次请求、单次发布、单个资源对象的身份
- 原始错误文本
- 原始 URL、Query、客户端地址
- 需要按单条请求回放的上下文

### 低频业务指标才允许有限业务维度

适用场景：

- 发布阶段结果
- 渲染任务结果
- observer / callback 分类
- pipeline / strategy / task 有限集合

约束：

- 业务标签必须是稳定枚举，不是原始对象 ID
- 如果一个标签值集合无法在评审时列出上界，就不应进入指标
- 高频请求事实与业务对象身份应分开建模，不要把 `devflow.release.id`、`manifest_id` 一类字段塞回 HTTP 指标

### 平台/运行时指标不承载服务业务语义

适用对象：

- `process_*`
- `go_*` / runtime 指标
- Collector 自身指标
- scrape / export / queue / batch 相关平台指标

约束：

- 这类指标由平台组件或运行时产生，不要求服务补业务标签
- 如果需要关联服务或环境，优先依赖 Resource、Collector enrichment 或 target metadata

---

## 6. 服务身份与环境字段的 owner 边界

服务和环境身份字段必须由最早且最稳定能确定它的一层负责，不能“谁拿得到谁都打一遍”。

| 字段 | canonical attribute | Prometheus-safe label | 默认 owner | 高频 HTTP 中的默认承载 |
|------|---------------------|-----------------------|------------|------------------------------|
| 服务名 | `service.name` | `service_name` | Resource | 平台元数据 |
| 服务命名空间 | `service.namespace` | `service_namespace` | Resource | 平台元数据 |
| 服务版本 | `service.version` | `service_version` | Resource | 优先用 `build_info` 类低频指标表达 |
| 部署环境 | `deployment.environment.name` | `deployment_environment_name` | Resource / Collector | 平台元数据 |
| 服务实例 | `service.instance.id` | `service_instance_id` | Resource | 不作为高频聚合标签 |

规则：

- canonical naming 在 Trace / Resource 侧继续使用点号命名，例如 `service.name`
- Prometheus label 仅在确有必要时使用下划线命名，例如 `service_name`
- 同一语义字段不应同时由服务代码、Collector、Prometheus 反复复制为多套近义标签
- 对 HTTP 高频应用指标，服务身份和环境身份默认通过平台元数据获得，不作为每条样本的默认 app-side 标签
- `service.version` 如果要在 Metrics 中暴露，优先放入 `build_info` 类低频指标，而不是默认进入每条高频 HTTP 指标

---

## 7. Prometheus 与 OTel 的 ownership 边界

平台必须把 Prometheus 和 OTel 的职责切开，否则会出现“服务乱打标签、Collector 重写语义、Prometheus 再复制一遍”的混乱状态。

| 层 | 负责什么 | 不负责什么 |
|----|----------|------------|
| 服务代码 | 只有业务代码知道的低基数业务维度；业务结果语义；少量场景化低频指标 | 平台环境元数据；Pod / Node / Cluster 身份；单请求 ID 聚合 |
| OTel SDK / instrumentation | 请求边界天然可得的 HTTP 事实；资源字段装载；trace context；exemplar 关联上下文 | 猜业务对象身份；补 K8s / cloud 平台落点 |
| OTel Collector | `k8s.*`、`deployment.environment.name`、集群/namespace/节点等 enrichment；trace-derived metrics pipeline | 改写服务已经确定的业务标签语义；把高基数原文变成 label |
| Prometheus | scrape target、`job`、`instance`、target labels、查询与告警聚合 | 发明业务语义；替服务推断路由或业务结果 |

强约束：

- OTel Collector 可以补平台元数据，不能改写服务已确定的业务语义
- Prometheus 可以附着 scrape target 元数据，不能承担业务字段归一化职责
- 服务代码禁止回填 Pod、Node、Cluster、Cloud 这类平台落点字段
- 平台不能期待 Collector 或 Prometheus 自动猜出只有业务代码知道的 `result`、`strategy`、`task_name`

---

## 8. 平台提供的 metadata

下面这类字段如果需要出现在观测查询里，优先来自平台，而不是由每个服务重复维护。

| 元数据 | 默认来源 | 主要用途 |
|--------|----------|----------|
| `job` | Prometheus scrape target metadata | 按抓取目标聚合与排障 |
| `instance` | Prometheus scrape target metadata | 按实例目标定位抓取异常 |
| `k8s.cluster.name` | OTel Collector enrichment | 跨集群查询与环境隔离 |
| `k8s.namespace.name` | OTel Collector enrichment | 命名空间级筛选 |
| `k8s.pod.name` | OTel Collector enrichment / target metadata | 单实例排障，不是高频指标聚合维度 |
| `k8s.node.name` | OTel Collector enrichment | 节点排障 |
| `host.name` | OTel Collector enrichment | 主机排障 |
| `cloud.region` | OTel Collector enrichment | 区域切片 |
| `deployment.environment.name` | Resource / Collector | 环境切片 |

规则：

- 这些字段主要服务于查询过滤、落点定位、跨环境隔离
- 它们不应默认复制成每一条高频 HTTP 应用指标的标签
- 如果平台侧已有稳定元数据，应用侧同义 label 应删除而不是长期双写

---

## 9. Trace-derived metrics 与 exemplar

Trace-derived metrics 是补充面，不是替代面。

### Trace-derived metrics

允许：

- 通过 OTel Collector 的 `spanmetrics` 一类能力派生 request rate、error rate、latency histogram
- 用于平台级补充视图、跨语言兜底视图或对齐 trace pipeline 健康

不允许：

- 因为 trace 已能派生 RED 指标，就删除原生 HTTP metrics
- 把 trace 里所有属性无差别下沉成 metrics labels

### Exemplar

exemplar 是 Metrics 到 Trace 的推荐关联方式。

规则：

- `trace_id` 允许出现在 exemplar 中
- `trace_id`、`span_id` 禁止作为高频 metrics label
- exemplar 只负责从聚合点跳到代表性 Trace，不负责替代日志或 span 属性
- 如果采样、存储或链路限制导致 exemplar 不完整，也不能因此把请求主键塞进 label

---

## 10. 禁止标签

下面这些标签在 target state 中默认禁止进入高频 Metrics；多数情况下也不应进入低频业务指标，除非文档明确给出例外。

| Label | 为什么禁止 | 更合适的去处 |
|-------|------------|--------------|
| `trace_id` | 每请求唯一，基数无限 | exemplar / Trace / Log |
| `span_id` | 每 span 唯一，基数无限 | Trace / Log |
| `request_id` | 高基数，且常与 `trace_id` 重叠 | Log / Trace |
| `user_id` | 用户规模无界 | Trace / Log / DB |
| `client.address` | 地址数量无界，且噪声大 | Log / 安全审计 |
| `user_agent.original` | 高基数原文，不适合聚合 | Log |
| `url.path` | 原始路径常含动态 ID | Log / Trace |
| `url.query` | 高基数且易带敏感信息 | Log（脱敏后按需） |
| `error.message` | 自由文本不可聚合 | Log `message` / Trace |
| `caller` | 实现细节，不是指标维度 | Log |
| `logger.name` | 日志分类，不是指标标签 | Log |
| `release_id` / `devflow.release.id` | 高频变化的对象 ID | Trace / 业务日志 |
| `manifest_id` / `devflow.manifest.id` | 高频变化的对象 ID | Trace / 业务日志 |
| `devflow.application.id` | 业务对象 ID，基数通常不可控 | Trace / 业务日志 |
| `devflow.environment.id` | 业务对象 ID，基数通常不可控 | Trace / 业务日志 |
| `k8s.pod.name` | 高频滚动变化，容易打碎序列 | Resource / target metadata |
| `host.name` | 同上 | Resource / target metadata |

禁止原则：

- 不把单请求主键打成 Metrics label
- 不把自由文本打成 Metrics label
- 不把原始对象 ID 打成高频 Metrics label
- 不把平台落点字段复制成每条应用指标的默认标签

---

## 11. 验证清单

平台和服务在验收一组 Metrics 规范是否达标时，至少检查下面这些问题：

- [ ] HTTP 高频指标只包含 `http_request_method`、`http_route`、`http_response_status_code` 这组最小必需标签，或经过明确评审后的极少量可选标签
- [ ] `http_route` 使用模板路由，而不是原始动态路径
- [ ] `service_name`、`service_namespace`、`deployment_environment_name` 等身份维度在系统层可稳定获得，且高频 HTTP 指标优先通过 Resource、Collector 或 Prometheus target metadata 承载
- [ ] 平台侧已有同义元数据时，应用指标没有长期双写重复标签
- [ ] 低频业务指标中的 `result`、`action`、`strategy`、`task_name` 等值集合已经证明是有限且稳定的
- [ ] `trace_id`、`span_id`、`request_id`、`user_id`、原始 `url.path`、`error.message` 没有进入 Metrics labels
- [ ] `k8s.pod.name`、`host.name`、`instance` 这类落点字段没有被当作高频应用指标默认切片
- [ ] 原生 HTTP metrics 仍然存在，没有被 trace-derived metrics 替代
- [ ] exemplar 用于 Metrics -> Trace 关联，而不是把请求主键改写成 label
- [ ] Prometheus 与 OTel 的 ownership 已经清晰：Prometheus 负责 target metadata，Collector 负责 enrichment，服务只负责业务代码才知道的低基数语义

---

## 12. 相关文档

- [字段命名与来源边界](../../observability/contracts/attributes/)
- [信号字段契约](../../observability/contracts/standard/)
- [信号标签矩阵](../../observability/contracts/signal-label-matrix/)
- [HTTP 字段边界](../http/)
