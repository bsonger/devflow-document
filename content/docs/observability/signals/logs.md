---
title: "Logs 字段规范"
weight: 75
---

# Logs 字段规范

<span class="df-badge">Logs</span> <span class="df-badge">Loki</span> <span class="df-badge">OpenTelemetry</span> <span class="df-badge">Platform</span>

这页是 `contracts/` 通用日志契约在 **Logs** 这一类信号上的目标态细化页。
它面向运维、平台、SRE，重点只回答执行层真正要统一的几件事：

- 结构化日志最小字段集是什么
- 不同日志类别各自必须补哪些字段
- 哪些字段由服务负责，哪些字段由平台或 Collector 注入
- Loki 的 label 应如何严格收敛

这页不是实现教程，也不重写 `contracts/` 中的完整字段字典。
canonical naming 仍以 [字段命名与来源边界](../../observability/contracts/attributes/)、[信号字段契约](../../observability/contracts/standard/) 和 [结构化日志规范](../../observability/contracts/logging/) 为准；这里负责把那套命名落实成 Logs 的 target-state ownership 规则。

如果你当前关心的是 **HTTP request boundary** 上字段该如何在 Metrics / Logs / Traces 间拆分，优先看 [HTTP 字段边界](../http/)；这页只保留 Logs 全局规则，不重复展开每个 HTTP 字段的边界解释。

---

## 1. 共享基础日志字段

所有进入目标态的结构化日志都共享同一组 base fields。缺少这组字段的日志，不满足 DevFlow 当前 Logs baseline。

| 字段 | 作用 | 默认 owner |
|------|------|------------|
| `timestamp` | 事件发生时间 | 日志 SDK / encoder |
| `severity_text` | 严重级别 | 服务日志库 |
| `logger.name` | 日志分类主键 | 服务 |
| `message` | 稳定的人类可读事件文本 | 服务 |
| `caller` | 回到源码位置的调试字段 | 日志 SDK / encoder |
| `trace_id` | Trace -> Log 主关联键 | SDK / 当前 span context |
| `span_id` | 当前 span 关联键 | SDK / 当前 span context |

强约束：

- `logger.name` 是分类主键，`caller` 只是调试字段，二者不能互相替代。
- `trace_id` / `span_id` 必须来自当前 span context，不允许服务手工拼接。
- `message` 是当前推荐文本字段；新日志不再引入 `body` 作为同义字段。
- `request_id` 只允许作为 legacy 兼容字段按需保留，不再作为 target-state 主关联键。

ownership 规则：

- 服务负责决定日志属于哪一类事件，因此负责写入稳定的 `logger.name` 和有排障意义的 `message`。
- SDK 负责传播 trace context；平台不负责替服务猜测 `trace_id` / `span_id`。
- 编码器或日志库负责稳定产出 `timestamp`、`caller` 等通用日志元信息。

---

## 2. HTTP access logs

`http.access` 表示“请求完成且需要留下入口访问事实”的结构化日志。
这类日志只保留最小请求边界事实和 Trace 关联键，不承担平台身份重复、业务对象建模或聚合指标职责。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| 共享基础字段 | 时间、分类、文本、Trace 关联 | 服务 / SDK / 日志 encoder |
| `http.request.method` | 区分入口动作 | 框架 / middleware |
| `http.route` | 聚合到模板路由 | 框架 / middleware |
| `url.path` | 保留原始路径用于单次排障 | 框架 / middleware |
| `http.response.status_code` | 识别请求结果段位 | 框架 / middleware |

补充约束：

- `http.route` 必须是模板路由，不允许写入带动态 ID 的原始路径。
- `url.path` 允许保留原始路径，但它的用途是单请求排障，不应升级为 Loki label。
- 普通 access log 不默认重复 `service.*`、`deployment.environment.name`、`k8s.*`、`cloud.*`、`result`、`duration_ms`、请求级 `devflow.*.id`。
- `http.response.body.size` 在普通 access log 中，若稳定可得，推荐保留。
- `http.request.body.size` 只在稳定可得且确有排障价值时按需出现。

更细的 HTTP request-boundary 字段拆分、可选字段和禁止重复字段，统一看 [HTTP 字段边界](../http/)。

---

## 3. HTTP error logs

`http.error` 用于 4xx、5xx、panic recovery 或其他需要明确失败语义的入口日志。
它继承 `http.access` 的请求边界最小集，但在错误场景下对分类和错误文本有更严格要求。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| 共享基础字段 | 时间、分类、文本、Trace 关联 | 服务 / SDK / 日志 encoder |
| `logger.name` | 必须固定为 `http.error` | 服务 |
| `message` | 必须承载具体失败文本或 panic 摘要 | 服务 |
| `http.request.method` | 识别失败入口动作 | 框架 / middleware |
| `http.route` | 稳定聚合到模板路由 | 框架 / middleware |
| `url.path` | 保留原始请求路径 | 框架 / middleware |
| `http.response.status_code` | 区分 4xx / 5xx / panic 场景 | 框架 / middleware |

继承规则：

- 4xx 通常记为 `WARN`；5xx 和 panic 通常记为 `ERROR`。
- 错误文本优先直接进入 `message`，不要再并行创建自由格式的 `error.message` 日志字段去重复它。
- 更细的请求边界分解、额外字段和不应重复的字段统一看 [HTTP 字段边界](../http/)。

---

## 4. 业务事件日志

`business.event` 用于记录业务对象创建、变更、绑定、提交、回调处理等控制面事件。
这类日志的 owner 明确偏向服务，因为只有业务代码知道对象语义、动作含义和业务结果。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `logger.name` | 固定为 `business.event` | 服务 |
| `operation` | 说明执行了什么动作 | 服务 |
| `resource` | 说明动作作用于什么资源类别 | 服务 |
| `result` | 说明业务结果是成功、拒绝还是失败 | 服务 |

建议字段：

| 字段 | 何时应该带 | 默认 owner |
|------|------------|------------|
| 稳定的 `devflow.*.id` | 事件天然绑定业务对象，且该 ID 是稳定主键时 | 服务 |
| `resource_id` | 资源主键不是 `devflow.*.id` 但仍需反查时 | 服务 |
| `error_code` | 存在稳定、枚举化的业务错误码时 | 服务 |

约束：

- `operation`、`resource`、`result` 必须是稳定、有限、可运营理解的枚举，不允许把自由文本塞进这些字段。
- 业务对象 ID 可以进入日志 JSON，但不应自动变成 Loki label。
- 平台不负责补业务对象语义；Collector 也不能改写服务已经确定的 `operation`、`resource`、`result`。

---

## 5. 生命周期 / mutation logs

这类日志用于承载“系统执行到了哪一步、对哪个对象做了什么变更、最终结果如何”的流程状态。
当前 canonical 分类主要包括 `release.lifecycle`、`runtime.state`、`worker.lifecycle`、`service.lifecycle`，共同规则是一致的：日志语义由服务定义，平台只补环境和运行落点。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `logger.name` | 固定为对应 lifecycle / mutation 分类 | 服务 |
| `operation` | 标识当前阶段或动作 | 服务 |
| `resource` | 标识当前对象类别或系统部件 | 服务 |
| `result` | 标识当前阶段结果 | 服务 |

常见建议字段：

| 字段 | 适用场景 | 默认 owner |
|------|----------|------------|
| `devflow.release.id` | release / manifest / rollout 生命周期 | 服务 |
| `devflow.manifest.id` | manifest 渲染、发布编排 | 服务 |
| `devflow.application.id` | runtime 同步、状态回写 | 服务 |
| `devflow.environment.id` | 环境级 observer / runtime 操作 | 服务 |
| `dependency` / `dependency_operation` | 生命周期中伴随外部依赖调用时 | 服务 |
| `duration_ms` | 低频阶段性动作，且日志本身承担步骤耗时说明时 | 服务 |

分类约束：

- `release.lifecycle`、`runtime.state` 等是稳定的 `logger.name` 分类，不允许临时拼出新的自由格式分类名。
- `duration_ms` 只适合低频 lifecycle / mutation 日志，不应回灌到高频 `http.access`。
- lifecycle / mutation 日志的主价值是表达阶段、对象和结果，而不是替代 Span 全量属性。

---

## 6. 下游调用与数据库日志

这两类日志同样属于稳定 contract category，但在 signal-level 上只需要保留最小分类语义和 ownership 边界，不需要在这里重写完整字段字典。

### `external.call`

`external.call` 用于记录对下游 HTTP、Kubernetes、Argo CD、Tekton 或其他外部依赖的调用结果。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `logger.name` | 固定为 `external.call` | 服务 |
| `operation` | 说明本服务当前在做什么调用动作 | 服务 |
| `resource` | 说明调用发生在哪类资源或子系统边界 | 服务 |
| `dependency` | 标识被调用依赖 | 服务 |
| `dependency_operation` | 标识对依赖执行的动作 | 服务 |
| `result` | 标识调用结果 | 服务 |

规则：

- `dependency`、`dependency_operation`、`result` 是服务语义，不由平台推断或改写。
- 这类日志可以带 `http.response.status_code`、`duration_ms`、稳定错误码，但这类扩展字段按需出现。
- 业务依赖名和下游对象 ID 可以存在于日志 JSON 中，但默认不是 Loki label material。

### `db.query`

`db.query` 用于记录 repository 查询、持久化写入或其他数据库访问结果。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `logger.name` | 固定为 `db.query` | 服务 |
| `operation` | 说明当前 repository / persistence 动作 | 服务 |
| `resource` | 固定表达数据库访问这一类资源边界 | 服务 |
| `db.system` | 标识数据库类型 | 服务 |
| `db.operation` | 标识查询、插入、更新、删除等动作 | 服务 |
| `result` | 标识访问结果 | 服务 |

规则：

- `db.system`、`db.operation`、`result` 都属于服务已知语义，平台不负责猜测。
- 如需补充 `db.collection`、`duration_ms`、稳定错误码，应按排障价值按需增加。
- SQL 文本、原始参数、对象 ID 不应升级为 Loki label；如必须记录，也应先满足脱敏和基数约束。

---

## 7. Resource 身份字段与平台 enrichment 字段

Logs 里的非业务元数据需要先拆成两类：

- 服务身份字段：canonical 上属于 Resource，可见于日志查询，但不应被描述成“平台注入”
- 平台 enrichment 字段：由 Collector 或平台侧统一补齐

### 服务身份字段（Resource-visible）

| 字段 | 典型来源 | 默认 owner | 说明 |
|------|----------|------------|------|
| `service.name` | Resource | 服务配置 / SDK | 服务身份，优先存在于 Resource |
| `service.namespace` | Resource | 服务配置 / SDK | 服务命名空间 |
| `service.version` | Resource | 服务配置 / SDK | 版本维度，按需用于查询 |
| `service.instance.id` | Resource | SDK | 实例身份，不是默认高频检索键 |

规则：

- 这组字段的 canonical 归属是 Resource，不是平台运行落点 enrichment。
- 服务负责声明服务身份；SDK 负责把它们装载进 Resource。
- 普通高频日志不要求服务把这些字段手工重复打印进日志正文。

### 平台 enrichment 字段

| 字段 | 典型来源 | 默认 owner | 说明 |
|------|----------|------------|------|
| `deployment.environment.name` | Resource / Collector enrichment | 平台 | 环境身份 |
| `k8s.cluster.name` | Collector enrichment | 平台 | 集群身份 |
| `k8s.namespace.name` | Collector enrichment | 平台 | K8s namespace |
| `k8s.pod.name` | Collector enrichment | 平台 | Pod 落点 |
| `k8s.container.name` | Collector enrichment | 平台 | 容器落点 |
| `k8s.node.name` | Collector enrichment | 平台 | 节点落点 |
| `host.name` | Collector enrichment | 平台 | 主机维度 |
| `cloud.region` | Collector enrichment | 平台 | 云地域 |

规则：

- 平台负责统一补齐 `deployment.environment.name`、`k8s.*`、`cloud.*` 这类环境与运行落点字段。
- 服务不应手工回填 Pod、Node、Cluster、Region 这类平台侧身份。
- 平台可以 enrich，但不能改写服务已经确定的业务字段语义。

---

## 8. Loki label restrictions / 不应成为 labels 的字段

Loki label 必须严格限制在低基数、稳定、适合 stream 切分的字段上。
目标态里，大部分业务、请求和调试字段都**允许存在于日志 JSON**，但**不允许升级为 Loki label**。

如果 Loki 需要把某些 canonical 字段放入 label carrier，应显式使用“canonical field -> label-form carrier”的映射，而不是把 label 名误当成新的 canonical 字段。例如：

- `service.name` -> `service_name`
- `service.namespace` -> `service_namespace`
- `deployment.environment.name` -> `deployment_environment_name`
- `logger.name` -> `logger_name`
- `k8s.namespace.name` -> `k8s_namespace_name`

默认可接受的低基数 label，应尽量只收敛在这类服务身份、环境身份和少数稳定分类上。

下面这些字段不应成为 Loki label：

| 字段 | 为什么不应成为 label | 更合适的位置 |
|------|----------------------|--------------|
| `trace_id` | 基数无限，label 爆炸 | 日志 JSON / Trace 关联 |
| `span_id` | 同上 | 日志 JSON / Trace 关联 |
| `request_id` | 高基数且与 `trace_id` 功能重叠 | legacy JSON 字段 |
| `url.path` | 原始动态路径基数不可控 | 日志 JSON |
| `url.query` | 高基数且可能携带敏感信息 | 脱敏后的日志 JSON，且仅按需 |
| `client.address` | 噪声高、基数高 | 日志 JSON / 安全审计 |
| `user_agent.original` | 高基数 | 日志 JSON |
| `caller` | 代码位置高离散，不是运维切分键 | 日志 JSON |
| `message` | 自由文本不可索引为稳定 label | 日志正文 |
| `http.route` | 路由数可能快速膨胀，不适合作为 stream 维度 | 日志 JSON / 查询过滤 |
| `http.response.status_code` | 高频且组合后放大量大 | 日志 JSON / 查询过滤 |
| `operation` | 不同域会快速漂移，缺乏全局稳定上界 | 业务日志 JSON |
| `resource` | 同上 | 业务日志 JSON |
| `result` | 查询时过滤即可，不必进入 stream 切分 | 业务日志 JSON |
| 任意 `devflow.*.id` | 业务对象 ID 基数不可控 | 业务日志 JSON / Trace |
| `k8s.pod.name` | 实例滚动频繁，stream 数会爆炸 | 平台元数据查询 / JSON |

强约束：

- “字段有价值”不等于“字段可以做 label”。
- label 只服务于低基数 stream 切分；单请求排障依赖 JSON 字段检索和 `trace_id` 关联。
- 新增 Loki label 前必须先证明其值集合上界稳定、跨服务含义一致、且确实需要作为 stream 维度。

---

## 9. 反模式

### 反模式 1：把平台身份字段手工复制进每条高频请求日志

表现：

- 每条 `http.access` 都带 `service.name`、`deployment.environment.name`、`k8s.pod.name`

问题：

- 高频日志被平台元数据淹没
- 服务与平台双写同义字段，后续容易漂移

目标态做法：

- 平台身份优先放在 Resource 或 Collector enrichment

### 反模式 2：把自由文本错误拆成多个近义字段

表现：

- `message` 写了一遍失败描述
- 同时再写一个自由格式 `error.message`

问题：

- 查询口径分裂
- 无法形成统一检索路径

目标态做法：

- 具体失败文本优先统一进入 `message`

### 反模式 3：把 `caller`、`trace_id`、`devflow.release.id` 等字段升级成 Loki label

问题：

- 高基数导致 stream 爆炸
- 查询和存储成本快速上升

目标态做法：

- 这些字段保留在日志 JSON 中，通过字段过滤和 Trace 关联使用

### 反模式 4：让 Collector 或平台改写业务语义

表现：

- 平台根据日志内容猜测 `result`
- Collector 把服务写出的 `operation` 统一重命名

问题：

- ownership 混乱
- 同一业务语义在不同服务间失真

目标态做法：

- 业务语义只由服务定义；平台只补环境和运行落点

### 反模式 5：把业务对象 ID 强行塞进所有 HTTP access logs

问题：

- 普通入口访问日志被与请求边界无关的业务字段淹没
- 高基数字段被误当成默认请求事实

目标态做法：

- `devflow.*.id` 优先放在业务事件日志、lifecycle 日志或相关 span 上

---

## 10. 验证清单

- [ ] 每条目标态结构化日志都有 `timestamp`、`severity_text`、`logger.name`、`message`、`caller`、`trace_id`、`span_id`
- [ ] `logger.name` 只使用已约定的稳定分类，如 `http.access`、`http.error`、`business.event`、`release.lifecycle`、`runtime.state`
- [ ] HTTP access logs 只保留请求边界最小事实，不默认重复平台身份和业务对象 ID
- [ ] HTTP error logs 的 `message` 能直接表达具体失败文本或 panic 摘要
- [ ] 业务事件日志和 lifecycle / mutation logs 都显式带 `operation`、`resource`、`result`
- [ ] 稳定的 `devflow.*.id` 只在确有业务语义的日志中出现，不被要求出现在每条普通请求日志
- [ ] `service.*` 作为 Resource 身份存在；`deployment.environment.name`、`k8s.*`、`cloud.*` 等平台字段由平台 enrichment 补齐，而不是服务手工双写
- [ ] Loki labels 只保留低基数、稳定、跨服务一致的字段；`trace_id`、`span_id`、`caller`、`url.path`、任意 `devflow.*.id` 均未进入 label 集合
- [ ] 平台没有改写服务已确定的 `operation`、`resource`、`result` 等业务语义
- [ ] 值班工程师能够从 Metrics / Trace 进入日志，并按 `trace_id` 稳定反查单次请求或单次业务事件

满足这份清单，Logs 才算达到当前 DevFlow observability 的 target state。
