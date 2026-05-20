---
title: "Traces 字段规范"
weight: 76
---

# Traces 字段规范

<span class="df-badge">Traces</span> <span class="df-badge">OpenTelemetry</span> <span class="df-badge">Span</span> <span class="df-badge">Platform</span>

这页是 `contracts/` 通用字段契约在 **Traces** 这一类信号上的目标态细化页。
它面向运维、平台、SRE，重点只回答执行层真正要统一的几件事：

- 一条 Trace 最少必须具备哪些 identity、span 和 Resource 语义
- 哪些字段属于根 span、内部 span、下游 client span、异步/后台 span
- 哪些字段应由框架、服务、SDK / 当前 span context、Resource、Collector 负责
- 平台在查询和排障时，应该从 Trace 稳定读到哪些跨环境身份

这页不是实现教程，也不重写 `contracts/` 的完整字段字典。
canonical naming 仍以 [字段命名与来源边界](../contracts/attributes/)、[信号字段契约](../contracts/standard/) 和 [发布链路 Trace 示例](../release-trace-example/) 为准；这里负责把那套命名落实成 Traces 的 target-state ownership 规则。

如果你当前关心的是 **HTTP request boundary** 上入口 span 该如何映射 method / route / status，优先看 [HTTP 字段边界](../http/)；这页只保留 Traces 全局规则，不重复展开整套 HTTP server 映射。

---

## 1. request / trace identity 与 root span 规则

Trace 的目标不是“记录很多 span”，而是稳定回答两件事：

- 这是不是同一条链路
- 这条链路的入口和根语义到底是什么

这里需要先把三个概念拆开：

- `trace_id`：整条链路的主键
- `span_id`：当前 span 的主键
- root span：当前链路对运维最有价值的入口或触发边界

### required identity

| 字段 | 作用 | 默认 owner |
|------|------|------------|
| `trace_id` | Trace -> Log / exemplar / 下游链路关联主键 | SDK / 当前 span context |
| `span_id` | 当前 span 主键 | SDK / 当前 span context |
| `span.name` | 稳定表达当前边界动作 | 框架 / middleware 或服务 |
| `span.kind` | 明确边界类型 | SDK / instrumentation |

### root span 目标态

| 场景 | root span 应该是什么 | 默认 owner |
|------|---------------------|------------|
| 同步入口请求 | 当前入口 server span | 框架 / middleware |
| 队列消费 / worker 拉起 | 当前消费或任务执行入口 span | SDK / instrumentation + 服务 |
| 定时任务 / controller 循环 | 当前调度批次或一次 reconcile 入口 span | 服务 |
| 回调处理 | 当前 callback 接收或处理入口 span | 框架 / middleware 或服务 |

约束：

- root span 必须对应一个真实的入口或触发边界，不允许为了“凑树形”额外包一层没有排障价值的空白 span。
- 有上游 trace context 时，当前入口 span 可以不是全局 trace root，但仍然必须是**本服务可见的入口边界 span**。
- 没有上游 trace context 时，SDK 负责创建新的 `trace_id`；服务不允许手工生成或拼接。
- `span.name` 必须稳定，不允许把请求 ID、对象 ID、动态 URL、错误文本拼进名称。
- HTTP 只是一个例子；HTTP method / route / status 的完整入口映射统一看 [HTTP 字段边界](../http/)。

对平台读者来说，最重要的一条是：

- 请求身份和 root span 语义必须先稳定，后续内部 span 再多才有排障价值。

---

## 2. internal span 规范

internal span 用来表达“当前服务内部执行到了哪个稳定阶段”，而不是把每一行代码都变成 span。

### internal span 必须回答的问题

- 这一步是哪个阶段
- 这一步依附于哪个父边界
- 这一步是否和某个稳定业务对象有关

### 命名与字段

| 字段 | 规则 | 默认 owner |
|------|------|------------|
| `span.name` | 用稳定阶段名，不带动态值 | 服务 |
| `span.kind` | 固定为 `internal` | SDK / instrumentation |
| `devflow.*.id` | 仅在该步骤天然知道该业务对象时显式带上 | 服务 |
| `error.type` / `error.message` | 仅在当前 span 失败时出现 | 服务 |

推荐命名模式：

- 领域阶段：`release.LoadApplicationContext`
- 编排阶段：`release.CreateManifest`
- 渲染阶段：`release.RenderBundle`
- 状态阶段：`runtime.WriteReleaseStatusBack`

约束：

- internal span 代表稳定阶段，不代表函数调用栈镜像。
- 不允许为纯 getter、简单 DTO 转换、无 I/O 的极短辅助函数普遍建 span。
- 父子层级应服务于排障，不应把一个阶段拆成十几个几乎没有独立意义的碎片 span。
- 业务对象字段优先挂在真正知道该对象的 span 上，不要求每个 internal span 机械重复全部 `devflow.*.id`。
- `error.message` 可以进入失败 span，但不应塞大段堆栈、原始 payload 或敏感原文。

对 release 链路来说，`release.LoadApplicationContext`、`release.CreateManifest`、`release.RenderBundle` 这一类名称已经是当前 canonical 参考，应保持一致，不要再并行创造 `load_context`、`RenderManifestBundle`、`releaseId` 这类变体。

---

## 3. downstream client span 规范

client span 用来表达“本服务正在调用哪个下游边界，以及结果如何”。它的价值在于把“服务内部慢”与“外部依赖慢”清楚拆开。

### client span 必备语义

| 字段 | 规则 | 默认 owner |
|------|------|------------|
| `span.name` | 用稳定依赖名 + 动作名 | 服务或 instrumentation |
| `span.kind` | `client` | SDK / instrumentation |
| 依赖协议事实 | 如 HTTP / gRPC / DB / K8s client 天然可得字段 | 框架 / instrumentation |
| 业务上下文 | 当前调用天然已知的 `devflow.*.id` | 服务 |
| 错误语义 | 当前调用失败时的 `error.type` / `error.message` | 服务 |

推荐命名模式：

- 跨服务 API：`meta-service.GetApplication`
- 配置读取：`config-service.ListAppConfigs`
- 平台依赖：`tekton.TriggerPipelineRun`
- 部署依赖：`argocd.CreateApplication`
- 制品依赖：`registry.PushBundle`

约束：

- client span 必须表达依赖边界，而不是复刻调用端内部函数名。
- 如果自动 instrumentation 已产出稳定的下游协议字段，服务不应再手工创建同义字段覆盖它。
- 失败依赖调用必须在对应 client span 上可见，而不是只在父 internal span 上抽象成“调用失败”。
- client span 可以携带当前调用天然已知的 `devflow.release.id`、`devflow.manifest.id` 等对象身份，但不应把整个请求体、响应体、认证头、token、完整 SQL 文本写进去。
- 平台不负责猜测依赖名；`dependency` 之类日志字段属于 Logs 侧 contract，不替代 Trace 命名。

---

## 4. async / background / callback span 规范

异步、后台、回调链路是最容易把 Trace 打断的地方。目标态要求这里仍然能看见“谁触发了谁、当前处理的是哪类动作、链路为何继续或重启”。

### 适用边界

- 队列生产 / 消费
- worker / controller / observer 执行
- 定时任务 / 补偿任务
- 第三方 webhook / 平台 callback
- 发布后续观察与状态回写

### 目标态规则

| 场景 | 必须表达什么 | 默认 owner |
|------|--------------|------------|
| producer span | 谁发出了异步任务、意图是什么 | 服务 |
| consumer span | 谁接收并开始处理该任务 | SDK / instrumentation + 服务 |
| callback 入口 span | 哪个外部系统或内部组件触发了回调 | 框架 / middleware 或服务 |
| 后台 reconcile / watcher span | 当前观察对象和当前阶段 | 服务 |

推荐命名模式：

- producer：`release.EnqueueRolloutObserver`
- consumer：`runtime-service.WatchReleaseStatus`
- callback：`tekton.CallbackPipelineRun`
- 后台写回：`runtime.WriteReleaseStatusBack`

约束：

- 不能因为链路脱离 HTTP 请求，就放弃 `trace_id` 传播或重新发明 `request_id` 作为主关联键。
- 新起一条 Trace 是允许的，但必须在新的 root/consumer span 上保留足够的业务身份来完成排障闭环，例如 `devflow.release.id`。
- callback / background span 的名称必须体现动作边界，不允许统一叫 `worker.run`、`callback.handler` 这类无信息名称。
- 长生命周期 watcher 不应做成无限期不结束的 span；应切成一次消费、一次观察批次或一次状态写回这一类可排障单元。
- producer / consumer 之间是否能跨进程保留同一条 Trace，取决于传输与采样策略；但无论是否同 Trace，业务对象身份和稳定 span naming 都必须可查询。

---

## 5. Resource attributes 与平台可见的 Trace 身份

Trace 查询不只依赖 span 本身，还依赖一组**平台可见的稳定身份**。这组字段的 canonical 归属是 Resource，不应被误写成“每个 span 都要手工重复的普通属性”。

这里需要把两层语义明确拆开，避免和 `contracts/standard` 的 canonical baseline 读起来像冲突：

- **语义要求**：`service.name`、`service.namespace` 仍然是 core trace service identity，属于当前 Trace baseline 的必需身份。
- **实现载体偏好**：在 target-state ownership 上，这组身份优先通过 Resource 或 trace query-visible context 稳定出现，而不是要求服务代码把它们手工盖到每个 span 上。

### required trace-visible identity

| 字段 | 作用 | 默认 owner |
|------|------|------------|
| `service.name` | 服务主身份 | Resource |
| `service.namespace` | 服务命名空间 | Resource |

这组字段是平台侧最小 Trace 身份。无论查询系统最终把它展示在 span、resource 还是 trace metadata 视图中，值班工程师都必须能直接按它们筛选和定位链路。

### recommended trace-visible context

| 字段 | 作用 | 默认 owner |
|------|------|------------|
| `deployment.environment.name` | 环境身份 | Resource 或 Collector |
| `service.version` | 版本维度，支撑灰度/回滚/发布排障 | Resource |
| `service.instance.id` | 实例身份 | Resource / SDK |
| `k8s.cluster.name` | 集群身份 | Collector |
| `k8s.namespace.name` | namespace 身份 | Collector |
| `k8s.pod.name` | Pod 落点 | Collector |
| `k8s.container.name` | 容器落点 | Collector |
| `k8s.node.name` | 节点落点 | Collector |
| `cloud.region` | 云地域 | Collector |
| `host.name` | 主机落点 | Collector |

约束：

- `service.name`、`service.namespace` 在 canonical baseline 中仍然是 required core trace service identity；这里强调的是 target-state 首选载体，而不是降低它们的必需性。
- `service.name`、`service.namespace` 是 required trace-visible identity，不允许缺省为“查询时大概能推出来”。
- `service.*` 的 canonical owner 是 Resource；服务负责声明，SDK 负责装载。
- 首选通过 Resource 或等价的 trace-visible query context 暴露 `service.name`、`service.namespace`，这不等于要求服务代码在每个 span 上手工重复 stamping。
- `deployment.environment.name` 属于 recommended trace-visible context，可以来自 Resource 或 Collector；一旦提供，就必须稳定、单值、可查询。
- `k8s.*`、`cloud.*`、`host.*` 是平台落点，不应要求业务代码手工写入。
- 平台可见身份字段可以通过 Trace Resource / query 维度暴露，不要求每个 span 手工复制。
- `devflow.*.id` 属于请求或业务对象身份，不属于 Resource；禁止塞进 `OTEL_RESOURCE_ATTRIBUTES` 一类进程级配置。

---

## 6. Collector enrichment 字段

Collector 的职责是统一补环境和运行落点，不是替服务猜业务语义，也不是改写 SDK 已确定的 trace identity。

### Collector 可以安全 enrich 的范围

Collector 适合补齐这类字段：

- 平台与运行落点身份，例如 `k8s.*`、`host.*`、`cloud.*`
- 平台统一环境身份，例如 `deployment.environment.name`
- 其他对所有服务都成立、且平台能稳定单值给出的非业务上下文

### Collector 不应做的事

- 不推断 `devflow.release.id`、`devflow.application.id`、`devflow.manifest.id` 这类业务对象身份。
- 不改写服务已经确定的 `span.name`、`error.type`、`error.message`、`devflow.*` 语义。
- 不生成假的 root span、假的 parent-child 关系或假的下游依赖名。
- 不把高基数 payload、header、query string、原始路径无差别下沉成 span 属性。

判定原则：

- 只有当 Collector 能对所有服务、所有语言、所有实例稳定 100% 正确补齐时，才应该由 Collector 接管。
- 只要字段依赖业务语义、请求时机或应用内部上下文，就不属于 Collector。

---

## 7. release / runtime 特殊上下文

DevFlow 当前最需要 Trace 承载完整业务上下文的链路，是 release 与 runtime 相关操作。这里的目标态不是“所有 span 都带所有字段”，而是关键阶段必须能让值班工程师直接判断：

- 这是哪次发布
- 目标应用和环境是什么
- 当前卡在编排、构建、部署还是运行时回写

### release / runtime 链路推荐业务字段

| 字段 | 典型出现位置 | 默认 owner |
|------|--------------|------------|
| `devflow.project.id` | 入口 span、上下文加载阶段 | 服务 |
| `devflow.application.id` | 入口 span、runtime 观察阶段 | 服务 |
| `devflow.environment.id` | 入口 span、部署/观察阶段 | 服务 |
| `devflow.manifest.id` | manifest 创建、渲染、构建阶段 | 服务 |
| `devflow.release.id` | 发布入口、部署、观察、状态回写阶段 | 服务 |
| `devflow.intent.kind` | build / deploy / rollback / observe 这类稳定意图 | 服务 |
| `devflow.intent.status` | 仅在语义稳定、对排障有帮助时使用 | 服务 |

### release / runtime 命名对齐要求

当前 canonical 参考包括但不限于：

- `release.LoadApplicationContext`
- `release.CreateManifest`
- `release.CreateReleaseSnapshot`
- `release.RenderBundle`
- `tekton.TriggerPipelineRun`
- `registry.PushBundle`
- `argocd.CreateApplication`
- `runtime-service.WatchReleaseStatus`
- `runtime.WriteReleaseStatusBack`

约束：

- `devflow.release.id` 是发布链路最关键的业务身份，不允许写成 `releaseId`、`release_id` 或其他变体。
- `runtime-service.WatchReleaseStatus` 这类跨服务或后台观察 span，必须显式体现 runtime 责任边界，不能退化成含糊的 `watch_status`。
- `service.version` 应能与发布/运行时 Trace 同时出现，方便区分“是业务对象本身失败”还是“某个新版本实例开始失败”。
- 发布链路 Trace 示例页已经给出一条“可排障”的参考树；新的 release/runtime span naming 应向该示例收敛，而不是继续扩散。

---

## 8. 反模式

### 反模式 1：把业务对象 ID 塞进 Resource

现象：

- `devflow.release.id`、`devflow.application.id` 出现在 `OTEL_RESOURCE_ATTRIBUTES`

后果：

- 同一进程内不同请求共享错误对象身份
- 查询结果混淆，Trace 语义失真

### 反模式 2：root span 名称带动态值

现象：

- `POST /api/v1/releases/rel-123`
- `CreateRelease(rel-123)`

后果：

- span name 基数失控
- 查询和聚合不可维护

### 反模式 3：internal span 退化成函数调用栈镜像

现象：

- 一个请求内出现大量 `helper.*`、`mapper.*`、`util.*` span

后果：

- 真正有意义的阶段被噪声淹没
- Trace 体积膨胀，排障效率下降

### 反模式 4：下游失败只记在父 span，不落在 client span

现象：

- 只能看到 `release.RenderBundle failed`
- 看不到 `registry.PushBundle` 或 `argocd.CreateApplication` 的失败边界

后果：

- 无法区分内部逻辑失败还是外部依赖失败

### 反模式 5：异步链路重新发明 request identity

现象：

- worker / callback 只带 `request_id`
- `trace_id` 传播中断后没有任何稳定业务身份补偿

后果：

- 无法从入口链路继续追到后台处理
- Metrics -> Trace -> Log 关联闭环断裂

### 反模式 6：Collector 猜业务语义

现象：

- Collector 试图按 URL、header、body 推断 `devflow.release.id`

后果：

- 错误率高且不可维护
- 平台职责越界，语义漂移

### 反模式 7：把 payload、header、完整 query string 无差别塞进 span

现象：

- Trace 中出现大体积、敏感或高噪声原文

后果：

- 存储膨胀
- 敏感信息泄漏风险升高
- 查询价值低于成本

---

## 9. 验收清单

- [ ] 每条目标态 Trace 都能稳定看到 `trace_id`、`span_id`、`span.name`、`span.kind`
- [ ] 每条目标态 Trace 都能稳定看到 `service.name`、`service.namespace` 这组 required trace-visible identity
- [ ] 同步入口、异步消费、后台任务、callback 都有清晰的 root span 或服务入口边界 span
- [ ] `span.name` 只使用稳定名称，不包含对象 ID、原始 URL、错误文本或自由拼接参数
- [ ] internal span 代表稳定阶段，不是函数调用栈镜像
- [ ] 下游依赖调用都落在独立 client span 上，失败边界可直接识别
- [ ] release / runtime 关键链路使用 canonical naming，例如 `release.CreateManifest`、`tekton.TriggerPipelineRun`、`runtime-service.WatchReleaseStatus`
- [ ] 关键业务身份字段使用 canonical key，例如 `devflow.release.id`、`devflow.application.id`、`devflow.environment.id`
- [ ] `service.name`、`service.namespace` 由 Resource 稳定声明，`service.version`、`service.instance.id` 在需要时也能作为 Trace 可见上下文查询
- [ ] 若当前服务或环境要求环境维度排障，`deployment.environment.name` 能作为 recommended trace-visible context 通过 Collector 或 Resource 稳定查询
- [ ] `k8s.*`、`cloud.*` 等平台落点字段在需要时能通过 Collector 稳定查询
- [ ] Collector 没有推断或改写 `devflow.*`、`span.name`、错误语义或 parent-child 关系
- [ ] `devflow.*.id` 没有进入 Resource 级配置
- [ ] Trace 中未出现大体积 payload、敏感 header、完整 query string 等高噪声原文
- [ ] 值班工程师能从 Metrics exemplar 跳到 Trace，再按 `trace_id` 跳到 Log，完成闭环排障
