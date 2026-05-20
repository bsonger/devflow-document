---
title: "HTTP 字段边界"
weight: 73
---

# HTTP 字段边界

<span class="df-badge">HTTP</span> <span class="df-badge">Logs</span> <span class="df-badge">Metrics</span> <span class="df-badge">Traces</span>

这页是 `contracts/` 通用字段契约在 **HTTP request boundary** 上的目标态细化页。
`contracts/` 负责给出 canonical naming 和通用基线；这页不重写那套基线，而是把现有基线落实到 HTTP 请求这一类高频入口信号上，明确：

- HTTP 相关字段该放在哪种 signal
- 这些字段该由谁负责
- 哪些字段在 HTTP 场景下是 required / optional / forbidden
- 哪些字段不该在高频请求信号里默认重复

这页主要解决四个执行层问题：

1. 同一个 HTTP 请求在 Metrics、Logs、Traces 里各自最少要保留什么
2. 哪些字段必须出现，哪些字段只能按需出现，哪些字段默认不要重复
3. 字段最终该由框架 / middleware、服务、SDK / 当前 span context、Resource、Collector 还是 Prometheus 负责
4. 值班工程师如何从一个 HTTP 请求稳定完成 Metrics -> Trace -> Log 的关联闭环

这里的约束延续 `signals/` 的定位：

- 这是目标态规范页，不是实现说明页
- canonical naming 仍以 `contracts/` 中的字段契约为准
- 这页明确 HTTP 请求边界上的 ownership、placement 和字段等级
- owner 以“最早且最稳定能确定该字段的一层”为准

---

## 同一个 HTTP 请求在三种信号里的职责分工

假设同一条请求命中了 `GET /api/v1/releases/:id`：

- Metrics 负责回答“这条路由最近是不是变慢了、报错了、错误码段异常了”
- Trace 负责回答“这次请求经过了哪些 span、卡在哪个阶段、失败发生在哪个边界”
- Log 负责回答“这次请求的原始路径、具体错误文本、额外排障上下文是什么”

所以三种信号应该共享**最小关联语义**，而不是机械重复同一份字段。

阅读这页时只要记一条：

- Metrics 保留低基数、可聚合的 HTTP 事实
- Traces 保留完整请求边界和链路关联
- Logs 保留原始路径、事件文本和单请求排障上下文

---

## 1. HTTP access log required fields

`http.access` 表示“请求已完成且需要留下入口访问事实”的结构化日志。它的目标不是承载所有上下文，而是保留最小可关联、最小可排障事实。

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `timestamp` | 定位事件发生时间 | 日志 SDK / encoder |
| `severity_text` | 区分正常访问与异常访问级别 | 服务日志库 |
| `logger.name` | 明确日志分类，固定为 `http.access` | 服务 |
| `message` | 提供稳定的人类可读事件文本 | 服务 |
| `caller` | 支持从日志回到代码位置排查 | 日志 SDK / encoder |
| `trace_id` | 从 Log 反查同一条 Trace 的主键 | SDK / 当前 span context |
| `span_id` | 定位当前入口 span | SDK / 当前 span context |
| `http.request.method` | 区分 `GET` / `POST` 等入口动作 | 框架 / middleware |
| `http.route` | 稳定聚合到路由模板 | 框架 / middleware |
| `url.path` | 保留原始请求路径，便于单次排障 | 框架 / middleware |
| `http.response.status_code` | 判断请求结果与错误段位 | 框架 / middleware |

约束：

- `http.route` 必须是模板路由，不是原始动态路径
- `url.path` 允许保留原始路径，但它的价值只在 Log 和 Trace，不在 Metrics label
- `trace_id` / `span_id` 不允许由服务手写拼接，必须来自当前 span context
- `logger.name` 是分类主键，`caller` 不是分类字段

---

## 2. HTTP access log optional fields

下面这些字段对部分服务、部分边界或部分审计场景有价值，但不应成为所有 access log 的默认前提。

| 字段 | 何时应该带 | 默认 owner |
|------|------------|------------|
| `http.request.body.size` | 请求体大小稳定可得，且对排查上传/代理问题有帮助时 | 框架 / middleware |
| `http.response.body.size` | 普通 access log 推荐保留，尤其在响应体大小稳定可得时 | 框架 / middleware |
| `network.protocol.version` | 明确区分 HTTP/1.1 与 HTTP/2 行为差异时 | 框架 / middleware |
| `client.address` | 明确需要排查入口来源、代理链或限流命中时 | 框架 / middleware |
| `user_agent.original` | 需要分析客户端差异、SDK 兼容性或浏览器问题时 | 框架 / middleware |
| `server.address` | 网关、多监听地址或多入口实例并存时 | 框架 / middleware |
| `server.port` | 同一进程暴露多个 HTTP 端口且确实需要区分时 | 框架 / middleware |
| `url.query` | 仅在 query 参数本身是排障关键、且完成脱敏/裁剪时 | 框架 / middleware |

约束：

- 可选字段是“按需增加”，不是“只要能拿到就全部打印”
- `url.query` 只有在确认无敏感数据、且确有运维价值时才允许出现
- `client.address`、`user_agent.original` 适合做临时排障上下文，不适合作为默认检索分流键

---

## 3. HTTP access log fields that should not be repeated by default

这些字段并不是“永远不能存在”，而是**不应该在每条普通 HTTP access log 里默认重复**。原因通常只有三类：它们已由别处稳定提供、它们会污染高频日志、或者它们更像业务语义而不是请求边界事实。

| 字段 | 为什么默认不重复 | 更合适的归属 |
|------|------------------|--------------|
| `service.name` | 进程级稳定身份，不需要每条 access log 手工复制 | Resource |
| `service.namespace` | 同上 | Resource |
| `service.version` | 同上 | Resource |
| `service.instance.id` | 实例落点信息更适合作为 Resource | Resource |
| `deployment.environment.name` | 环境身份应统一来自平台侧 | Resource / Collector |
| `k8s.cluster.name` | 运行落点，不是请求事实 | Collector |
| `k8s.namespace.name` | 运行落点，不是请求事实 | Collector |
| `k8s.pod.name` | 运行落点，不是请求事实 | Collector |
| `k8s.node.name` | 运行落点，不是请求事实 | Collector |
| `cloud.region` | 平台环境上下文，不是请求事实 | Collector |
| `host.name` | 运行落点，不是请求事实 | Collector |
| `event.outcome` | 与状态码语义高度重复 | 查询层或 Trace |
| `result` | 普通 access log 不需要再抽象一层业务结果 | 服务业务日志 |
| `duration_ms` | 应优先通过 Metrics / Span duration 观察，而不是在每条 access log 重复 | Metrics / Trace |
| `trace_flags` | 对常规值班排障价值低 | Trace |
| `devflow.release.id` | 业务对象 ID，不是所有入口请求都天然具备 | 服务业务日志 / Trace |
| `devflow.application.id` | 同上 | 服务业务日志 / Trace |
| `devflow.environment.id` | 同上 | 服务业务日志 / Trace |
| `request_id` | 不是当前规范的跨信号主键，且常与 `trace_id` 重复 | legacy 兼容，仅按需保留 |

默认规则：

- access log 只保留“请求边界事实 + Trace 关联键”
- 服务身份、环境身份、Kubernetes 落点优先从 Resource / Collector 获取
- 业务对象 ID 优先放在更有业务语义的日志和 span 上，而不是要求每一条入口访问日志都重复

---

## 4. HTTP error log additional/required fields

`http.error` 用于 4xx、5xx、panic recovery 或其他需要强调失败语义的入口日志。当前 baseline 与现有 logging contract 对齐，保持最小集：它继承 `http.access` 的请求边界最小集，只通过固定的 `logger.name` 和更强的 `message` 错误语义来表达失败，不额外引入新的 HTTP 错误分类日志字段集。

### 继承字段中的固定要求

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `logger.name` | 仍是继承字段，但在错误日志中必须固定为 `http.error` | 服务 |
| `message` | 仍是继承字段，但在错误日志中必须承载具体失败文本或 panic 摘要 | 服务 |

### 当前基线下的可选字段

| 字段 | 何时应该带 | 默认 owner |
|------|------------|------------|
| `http.request.body.size` | 请求体大小与错误原因明显相关时 | 框架 / middleware |

错误日志规范：

- 4xx 通常用 `WARN`
- 5xx 与 panic 通常用 `ERROR`
- 具体错误文本优先直接进入 `message`
- 不要再并行创建自由格式的 `error.message` 日志字段去重复 `message`
- 当前 HTTP error baseline 先保持极简，和现有 logging contract 对齐
- 如果未来需要扩展 HTTP 错误分类日志字段，也应先更新 `contracts/` 中的日志契约，再在这里落到 HTTP 场景

---

## 5. HTTP metrics required labels

HTTP 高频应用指标默认只回答趋势、聚合和告警问题，因此 required label 必须严格收敛到低基数、稳定、可聚合集合。

| Label | 为什么必须有 | 默认 owner |
|-------|--------------|------------|
| `http_request_method` | 区分不同请求动作带来的时延与错误差异 | 框架 / middleware 或指标 SDK |
| `http_route` | 稳定聚合到模板路由级别 | 框架 / middleware 或指标 SDK |
| `http_response_status_code` | 区分成功、客户端错误、服务端错误 | 框架 / middleware 或指标 SDK |

说明：

- Metrics 使用下划线风格 label 名称，保持与现有指标约定一致
- 这三个 label 构成 HTTP request rate / error / latency 的最小聚合切片
- 如果平台需要按服务或环境切片，优先从 scrape target metadata、OTel Resource 或 Collector enrichment 获得，而不是把它们默认复制成每条应用指标 label

---

## 6. HTTP metrics optional labels

这些 label 只有在确有稳定运维价值、且基数受控时才建议使用。

| Label | 何时应该带 | 默认 owner |
|-------|------------|------------|
| `service_name` | 应用侧指标必须直接区分多个服务，且平台身份暂时无法稳定侧带时 | Resource |
| `service_namespace` | 同上，需要按命名空间切片时 | Resource |
| `deployment_environment_name` | 同一套指标需要显式分环境展示，且环境身份未被稳定侧带时 | Resource / Collector |
| `service_version` | 做灰度、版本对比或回滚观察时 | Resource |
| `result` | 非通用 HTTP 指标，而是低基数工作流/依赖指标时 | 服务 |
| `action` | 只在动作集合稳定、且不是原始路径变体时 | 服务 |

约束：

- 可选 label 不意味着“看到有用就加”，而是要先证明它能稳定切分 dashboard、告警或 SLO
- 对 HTTP 高频入口指标，`service_name`、`deployment_environment_name` 这类身份 label 默认不是必需
- 一旦平台侧已有稳定 target metadata，就不再要求应用侧复制同义 label

---

## 7. HTTP metrics forbidden labels

下面这些 label 会带来高基数、隐私风险、语义漂移或跨信号混淆，目标态明确禁止。

| Label | 为什么禁止 | 更合适的去处 |
|-------|------------|--------------|
| `trace_id` | 基数无限，破坏聚合；关联应通过 exemplar | exemplar / Trace / Log |
| `span_id` | 同上 | Trace / Log |
| `request_id` | 高基数且常与 `trace_id` 重叠 | Log / Trace |
| `url.path` | 原始动态路径基数不可控 | Log / Trace |
| `url.query` | 高基数且易携带敏感信息 | Log（脱敏后按需） |
| `client.address` | 高基数且噪声大 | Log / 安全审计 |
| `user_agent.original` | 高基数，不适合高频 HTTP 指标 | Log |
| `error.message` | 自由文本不可聚合 | Log `message` / Trace `error.message` |
| `caller` | 实现细节，不是业务聚合维度 | Log |
| `logger.name` | 日志分类，不是 HTTP 指标维度 | Log |
| `devflow.release.id` | 高基数业务对象 ID | Trace / 业务日志 |
| `devflow.application.id` | 同上 | Trace / 业务日志 |
| `devflow.environment.id` | 同上 | Trace / 业务日志 |
| `k8s.pod.name` | 实例维度高波动，导致序列膨胀 | Resource / target metadata |
| `host.name` | 同上 | Resource / target metadata |

禁止原则：

- Metrics 不负责单请求排障
- Metrics 不负责承载自由文本
- Metrics 不应该复制 Trace / Log 的关联主键

---

## 8. HTTP trace/span required attributes

这一节需要先把三个概念拆开，否则很容易把“链路身份”和“span 属性”混成一类：

- `trace_id`：整条请求链路的身份
- `span_id`：当前 HTTP 入口 span 的身份
- HTTP server span attributes：描述这次入口请求事实、请求边界语义和结果状态的属性集合

对运维 / 平台读者来说，目标态不是“把所有东西都叫 span attribute”，而是区分：

- 哪些值是关联主键
- 哪些值是 span 本身的身份
- 哪些值是附着在该 HTTP server span 上的请求属性

入口 HTTP server span 仍然是三种信号里最适合保留“请求事实 + 请求边界语义”的位置。

### 请求 / 链路 identity

| 字段 | 为什么必须有 | 默认 owner |
|------|--------------|------------|
| `trace_id` | 整条链路的主键，用于 Metrics exemplar、Trace、Log 之间的关联 | SDK / 当前 span context |
| `span_id` | 当前 HTTP 入口 span 的主键，用于定位当前请求边界 | SDK / 当前 span context |

说明：

- `trace_id` / `span_id` 是当前页必须关注的 HTTP request identity，但它们不是“随便补充的可选上下文”
- 对排障路径来说，它们首先是关联键，其次才是被查询系统展示出来的字段

### HTTP server span required attributes

下面这组字段是在 `contracts/` 现有 Trace 基线之上，按 HTTP 请求边界直接落到入口 server span 的必备属性。

| Attribute | 为什么必须有 | 默认 owner |
|-----------|--------------|------------|
| `span.name` | 稳定表达当前入口操作，通常以路由模板命名 | 框架 / middleware |
| `span.kind` | 明确这是 server 入口 span | 框架 / SDK |
| `http.request.method` | 表达入口请求动作 | 框架 / middleware |
| `http.route` | 表达稳定的路由模板 | 框架 / middleware |
| `http.response.status_code` | 表达结果状态 | 框架 / middleware |
| `url.path` | 保留单次请求原始路径，支持从 Trace 回到具体请求事实 | 框架 / middleware |
| `url.scheme` | 标识 `http` / `https` 等入口协议语义 | 框架 / middleware |

### 强烈建议的 HTTP server span attributes

| Attribute | 何时应该带 | 默认 owner |
|-----------|------------|------------|
| `server.address` | 多入口或多监听地址并存时 | 框架 / middleware |
| `server.port` | 同一服务多个监听端口需区分时 | 框架 / middleware |
| `network.protocol.version` | 需要区分 HTTP/1.1 与 HTTP/2 行为时 | 框架 / middleware |
| `client.address` | 需要分析来源或代理链时 | 框架 / middleware |
| `user_agent.original` | 需要分析客户端差异时 | 框架 / middleware |
| `error.type` | 需要在 Trace 中稳定标记错误类别时 | 服务 |
| `error.message` | 错误文本对链路排障有价值时 | 服务 |

### Trace-visible resource attributes / platform identity

下面这组字段对 Trace 查询、筛选和跨环境排障是必需或建议可见的，但它们的归属是 Resource / Collector 上下文，不应被表述成普通 HTTP server span request attributes。

| Attribute | 可见性等级 | 为什么应该在 Trace 中可见 | 默认 owner |
|-----------|--------------|--------------------------|------------|
| `service.name` | 必需 | 标识链路当前服务 | Resource |
| `service.namespace` | 必需 | 标识服务所在逻辑命名空间 | Resource |
| `service.version` | 建议 | 支持版本对比、灰度和回滚排查 | Resource |
| `deployment.environment.name` | 建议 | 支持跨环境筛选和环境级排障 | Resource / Collector |

说明：

- 这些字段在 Trace 中通常通过 Resource / Collector 上下文可见，而不是要求每个 HTTP server span 手工重复写入
- `deployment.environment.name`、`service.version` 这类平台或版本身份应保留在 Trace Resource / context，而不是并入普通 request span attributes
- 业务对象 ID 例如 `devflow.release.id` 是否应该进入口 span，取决于该请求是否天然已知该业务对象；不是所有 HTTP 请求都强制要求
- Trace 可以承载比 Metrics 更丰富的上下文，但仍不应该把大体积 payload、敏感原文或高噪声 blob 放进 span 属性

---

## 9. Cross-signal field mapping table

下表描述“同一个 HTTP 请求字段，在三种信号里应该如何出现，以及归谁负责”。

| 语义 | Logs | Metrics | Traces | 主 owner | 备注 |
|------|------|---------|--------|----------|------|
| 请求方法 | `http.request.method` | `http_request_method` | `http.request.method` | 框架 / middleware | 三种信号共享的最小请求事实 |
| 路由模板 | `http.route` | `http_route` | `http.route` | 框架 / middleware | Metrics 必须用模板路由，不允许原始路径 |
| 原始路径 | `url.path` | 不出现 | `url.path` | 框架 / middleware | 只用于单请求排障，不用于聚合 |
| 协议 | 不出现 | 不出现 | `url.scheme` | 框架 / middleware | 当前基线下保留在 Trace，不进入高频 Metrics 和普通 HTTP 日志 |
| 响应状态码 | `http.response.status_code` | `http_response_status_code` | `http.response.status_code` | 框架 / middleware | 允许查询层再派生 status class |
| Trace 主键 | `trace_id` | exemplar 中的 `trace_id` | `trace_id` | SDK / 当前 span context | 不允许成为 Metrics label |
| 当前 span 主键 | `span_id` | 不出现 | `span_id` | SDK / 当前 span context | Log 需要，Metrics 不需要 |
| 日志分类 | `logger.name` | 不出现 | 不出现 | 服务 | `http.access` / `http.error` |
| 事件文本 | `message` | 不出现 | 不出现 | 服务 | 错误文本优先留在 Log |
| 代码位置 | `caller` | 不出现 | 不出现 | 日志 SDK / encoder | 调试辅助字段，不参与聚合 |
| 服务名 | 按需来自 Resource | 按需来自 `service_name` 或 target metadata | 通过 Trace Resource / context 可见的 `service.name` | Resource | 不要求作为普通 request span 字段重复 |
| 服务命名空间 | 按需来自 Resource | 按需来自 `service_namespace` 或 target metadata | 通过 Trace Resource / context 可见的 `service.namespace` | Resource | 同上 |
| 服务版本 | 按需来自 Resource | 按需来自 `service_version` | 通过 Trace Resource / context 可见的 `service.version` | Resource | 只在灰度/版本对比场景有明显价值 |
| 部署环境 | 按需来自 Resource / Collector | 按需来自 `deployment_environment_name` | 通过 Trace Resource / context 可见的 `deployment.environment.name` | Resource / Collector | 平台身份，不应让服务手工散落维护 |
| K8s 落点 | 按需 enriched | 不出现 | enriched | Collector | `k8s.*` 不是 HTTP 请求边界最小集 |
| 请求体大小 | `http.request.body.size` | 不出现 | 按需出现 | 框架 / middleware | 适合特定上传/代理问题 |
| 响应体大小 | `http.response.body.size` | 不出现 | 按需出现 | 框架 / middleware | access log 可推荐保留，但不进入高频聚合 |
| 客户端地址 | 按需出现 | 不出现 | 按需出现 | 框架 / middleware | 高基数，只用于排障 |
| User-Agent | 按需出现 | 不出现 | 按需出现 | 框架 / middleware | 同上 |
| 错误类别 | 不作为当前 `http.error` log baseline 字段 | 不出现 | `error.type` 按需 | 服务 | HTTP 错误分类当前只在 Trace 侧按需引入 |
| 错误文本 | `message` | 不出现 | `error.message` 按需 | 服务 | Log 保留主文本，Trace 仅按需摘要 |

如何读这张表：

- 如果字段目的是聚合和告警，优先看 Metrics 列
- 如果字段目的是链路关联和阶段定位，优先看 Traces 列
- 如果字段目的是具体文本和单请求排障，优先看 Logs 列
- 如果同一语义跨信号都需要，命名必须稳定对齐，但不要求存储形态完全一样

---

## 10. Anti-patterns

下面这些做法在目标态明确视为反模式。

### 反模式 1：把原始 `url.path` 当成 Metrics label

结果：

- 指标基数迅速爆炸
- 仪表盘和告警无法稳定聚合
- 动态 ID、随机 token、深分页参数会污染序列

正确做法：

- Metrics 用 `http_route`
- `url.path` 只放在 Log 和 Trace

### 反模式 2：在每条 access log 里重复 `service.*`、`deployment.environment.name`、`k8s.*`

结果：

- 高频日志被大量平台身份字段淹没
- 不同服务手工维护同义字段，容易漂移
- 平台侧修正环境或集群命名时成本极高

正确做法：

- 进程级身份走 Resource
- 运行落点走 Collector enrichment
- access log 只保留请求事实和关联键

### 反模式 3：把 `trace_id`、`span_id` 做成 Metrics label

结果：

- 指标完全失去聚合价值
- 存储成本和查询成本急剧上升

正确做法：

- Metrics 通过 exemplar 关联 Trace
- `trace_id`、`span_id` 只在 Trace / Log 中作为主关联键出现

### 反模式 4：错误日志额外堆一个自由格式 `error.message`，同时 `message` 也写同样文本

结果：

- 字段语义重复
- 查询时需要同时兼容两套错误文本入口

正确做法：

- 错误文本优先进入 `message`
- 当前 `http.error` log baseline 不新增错误分类字段
- 如果确实需要稳定错误类别，优先按现有契约放到 Trace 侧 `error.type`

### 反模式 5：把业务对象 ID 默认塞进所有 HTTP 高频指标或普通 access log

结果：

- 指标序列快速膨胀
- 普通入口访问日志被与请求边界无关的业务字段淹没

正确做法：

- `devflow.*.id` 只在该请求天然已知、且确实需要排障语义时进入 Trace 或业务日志
- 不把它们作为 HTTP 高频指标 label 的默认组成部分

### 反模式 6：让服务自己散落维护 `deployment.environment.name`

结果：

- 同一环境在不同服务里可能出现多个拼写
- 环境切片不可依赖

正确做法：

- 环境身份由 Resource / Collector 统一注入
- 应用侧只在平台暂时做不到时短期兜底

### 反模式 7：把 access log 当成请求全量审计容器

结果：

- 日志量暴涨
- 敏感字段和大 payload 容易泄漏
- 真正关键字段反而被淹没

正确做法：

- access log 保持最小事实集
- 专门的审计日志、业务日志、下游调用日志承载额外语义

---

## 最小闭环检查

一条目标态 HTTP 请求至少应该满足：

1. Metrics 能按 `http_request_method`、`http_route`、`http_response_status_code` 稳定聚合
2. Trace 能按 `trace_id`、`span_id`、`http.request.method`、`http.route`、`http.response.status_code` 还原入口边界
3. Log 能按 `trace_id`、`span_id` 回查具体请求文本和原始路径
4. 服务身份与环境身份不靠每条 access log 手工重复
5. 高基数字段不进入 HTTP 高频指标 label

做到这五点，HTTP request 才算具备可维护的跨信号 target-state 映射。
