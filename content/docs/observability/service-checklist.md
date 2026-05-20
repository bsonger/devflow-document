---
title: "现有服务字段清单"
weight: 79
---

# 🧾 现有服务字段清单

<span class="df-badge">meta-service</span> <span class="df-badge">config-service</span> <span class="df-badge">network-service</span> <span class="df-badge">release-service</span> <span class="df-badge">runtime-service</span>

这页把“原则”进一步落到 DevFlow 五个服务应该重点打哪些字段、日志和指标。

目标不是要求每条日志或每个 Span 都完全一样，而是给每个服务一份**最小但够用**的观测清单。

这页不重复定义通用规范：

- 命名和来源边界看 [字段命名与来源边界](../contracts/attributes/)
- 完整字段契约看 [信号字段契约](../contracts/standard/)
- 最小必需字段看 [信号标签矩阵](../contracts/signal-label-matrix/)
- 日志专属规则看 [结构化日志规范](../contracts/logging/)

---

## 🧭 所有服务共同必备

### 启动层

- `service.name`
- `service.version`

### 版本指标层

- `build_info` 或等价版本常量指标

### Collector 层

- `deployment.environment.name`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`

### 请求层

- `trace_id`
- `span_id`
- `http.request.method`
- `http.route`
- `http.response.status_code`

---

## 📚 meta-service

### 这个服务最值得观测什么

- 元数据创建、更新、绑定是否成功
- 哪类对象最常失败
- 下游服务查询元数据时是否变慢

### 建议重点字段

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.cluster.id`
- `devflow.user.id`

### 建议关键指标

- 项目、应用、环境相关 API 的请求量、错误率、延迟
- 绑定类操作的成功率

### 典型观测场景

- 创建/更新项目
- 注册应用
- 创建环境
- 绑定应用到环境

### 推荐日志消息

- `project created`
- `project updated`
- `application registered`
- `environment created`
- `application environment binding created`

### 推荐关键 Span

- `meta.CreateProject`
- `meta.CreateApplication`
- `meta.BindApplicationEnvironment`

---

## 🧩 config-service

### 这个服务最值得观测什么

- 渲染前读取配置是否稳定
- 环境差异配置是否同步成功
- 配置来源是否清晰到应用和环境

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.config.kind`
- `devflow.config.mount_path`

### 建议关键指标

- `workload-config` / `app-config` 相关 API 的请求量、错误率、延迟
- 配置同步任务成功率和耗时

### 典型观测场景

- AppConfig 创建/更新
- 配置仓库同步
- 渲染前配置读取

### 推荐日志消息

- `workload config saved`
- `app config created`
- `config sync started`
- `config sync completed`
- `config read for rendering`

### 推荐关键 Span

- `config.ListWorkloadConfigs`
- `config.ListAppConfigs`
- `config.SyncConfigSource`

---

## 🌐 network-service

### 这个服务最值得观测什么

- 网络拓扑定义是否完整
- Route 是否能稳定按环境读取
- 发布渲染阶段拿到的端口和入口是否符合预期

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.route.host`
- `devflow.route.path`
- `devflow.service.port`

### 建议关键指标

- Service / Route 相关 API 的请求量、错误率、延迟
- 发布读取网络定义的失败率

### 典型观测场景

- Service 定义变更
- Route 定义变更
- 发布阶段网络配置读取

### 推荐日志消息

- `service spec saved`
- `route spec saved`
- `network spec loaded for release`

### 推荐关键 Span

- `network.GetServices`
- `network.GetRoutes`
- `network.ResolveRouteForEnvironment`

---

## 🚀 release-service

### 这个服务最值得观测什么

- 一次发布卡在哪个阶段
- 异步意图是否被领取、重试、失败
- 构建、渲染、部署、回写是否都能串到同一条链路

### 建议重点字段

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.manifest.id`
- `devflow.release.id`
- `devflow.intent.kind`
- `devflow.intent.status`
- `devflow.cluster.id`

### 建议关键指标

- 创建 Release、查询 Release、回滚操作的请求量、错误率、延迟
- 发布阶段耗时分布：创建 Manifest、触发构建、渲染、发布、部署、回写
- `intent` 执行成功率、重试次数、失败率

### 典型观测场景

- 创建 Manifest
- 创建 Release
- 触发 Tekton
- 渲染部署包
- 推送 OCI bundle
- 创建 Argo CD Application
- 回滚

### 推荐日志消息

- `manifest created`
- `release created`
- `build triggered`
- `intent claimed`
- `release rendering started`
- `release rendering completed`
- `release bundle published`
- `argo application created`
- `release deployment status updated`
- `release rollback started`

> release-service 是 observability 字段最重的服务，因为它串起了完整发布链路。

### 推荐关键 Span

- `release.LoadApplicationContext`
- `release.CreateManifest`
- `tekton.TriggerPipelineRun`
- `release.RenderBundle`
- `registry.PushBundle`
- `argocd.CreateApplication`
- `runtime-service.WatchReleaseStatus`

---

## 🛠️ runtime-service

### 这个服务最值得观测什么

- workload 和 pod 状态变化是否及时
- rollout 进度回写是否准确
- 运维操作是否成功落到 K8s

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.release.id`
- `devflow.cluster.id`
- `k8s.workload.kind`
- `k8s.workload.name`
- `k8s.pod.name`

### 建议关键指标

- workload / pod 查询类 API 的延迟和错误率
- rollout 回写延迟
- 删除 Pod、重启、扩缩容等操作成功率

### 典型观测场景

- Pod 状态变化
- Workload 健康状态更新
- 运维操作（重启/删 Pod/扩缩容）

### 推荐日志消息

- `workload observed`
- `pod ready status changed`
- `runtime operation requested`
- `runtime operation completed`

### 推荐关键 Span

- `runtime.ListWorkloads`
- `runtime.ListPods`
- `runtime.GetPodLogs`
- `runtime.DeletePod`
- `runtime.RestartWorkload`
- `runtime.ScaleWorkload`

---

## ✅ 最小落地建议

如果你不想一口气把所有字段都打全，建议优先级如下：

### P0

- `service.name`
- `trace_id`
- `devflow.application.id`

`deployment.environment.name` 建议由 Collector / 平台资源注入统一补齐，不作为每个服务手工维护的启动必填项。

### P1

- `devflow.release.id`
- `devflow.environment.id`
- `k8s.cluster.name`
- `k8s.pod.name`

### P2

- `devflow.manifest.id`
- `devflow.intent.kind`
- `devflow.intent.status`
- 依赖调用上下文（`db.operation` / `messaging.*`）

---

## 🧱 五个服务整改矩阵

这一节不是“建议有哪些字段”，而是按平台验收角度，把五个服务拆成**可以直接发整改单**的矩阵。

使用方式：

- `P0` = 不补会直接影响基础排障闭环
- `P1` = 不补不会立刻失明，但会明显降低定位效率
- `Signal` = 主要整改落点
- `默认 owner` = 这项整改应由谁负责完成

### meta-service

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | HTTP 指标补齐 `http_request_method` `http_route` `http_response_status_code` | Metrics | 框架 / middleware | 能按接口、路由、状态码看错误率和时延 |
| P0 | HTTP access / error log 补齐 `trace_id` `span_id` `logger.name` `message` | Logs | 框架 + 服务 | 能从日志反查请求链路 |
| P0 | 元数据创建、更新、绑定链路补 `devflow.project.id` `devflow.application.id` `devflow.environment.id` | Traces / Logs | 服务 | 能知道失败到底影响哪个项目、应用、环境 |
| P1 | 补 `meta.CreateProject` `meta.CreateApplication` `meta.BindApplicationEnvironment` 这类稳定 span naming | Traces | 服务 | 元数据操作可按阶段排障 |
| P1 | 补绑定类操作成功率和失败率指标 | Metrics | 服务 | 能区分“读接口慢”还是“绑定动作失败” |

### config-service

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | HTTP 指标补齐最小三元标签 | Metrics | 框架 / middleware | 配置查询与写入接口可稳定聚合 |
| P0 | 配置读取、配置变更日志补 `trace_id` `span_id` `logger.name` `message` | Logs | 框架 + 服务 | 渲染前后的配置问题可按请求定位 |
| P0 | 配置读取与同步链路补 `devflow.application.id` `devflow.environment.id` | Traces / Logs | 服务 | 能区分是哪个应用、哪个环境的配置异常 |
| P1 | 补 `config.ListWorkloadConfigs` `config.ListAppConfigs` `config.SyncConfigSource` | Traces | 服务 | 能分清是读取慢还是同步慢 |
| P1 | 为配置同步任务补低基数 `result` 指标 | Metrics | 服务 | 能统计同步成功率和失败率 |

### network-service

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | HTTP 指标补齐最小三元标签 | Metrics | 框架 / middleware | Route / Service API 可按路由聚合 |
| P0 | Route / Service 变更日志补 `trace_id` `span_id` `logger.name` `message` | Logs | 框架 + 服务 | 网络配置问题可回溯到单次操作 |
| P0 | 发布读取网络定义链路补 `devflow.application.id` `devflow.environment.id` | Traces / Logs | 服务 | 能判断是哪个应用、环境的入口配置异常 |
| P1 | 补 `network.GetServices` `network.GetRoutes` `network.ResolveRouteForEnvironment` | Traces | 服务 | 能分清读 Service 慢还是 Route 解析慢 |
| P1 | 网络定义读取失败率指标单独暴露 | Metrics | 服务 | 发布失败时能先从指标看到网络侧异常 |

### release-service

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | 发布入口 HTTP 指标补齐最小三元标签 | Metrics | 框架 / middleware | 发布 API 请求量、时延、错误率可稳定聚合 |
| P0 | 发布生命周期日志补 `trace_id` `span_id` `devflow.release.id` `devflow.application.id` `message` | Logs | 框架 + 服务 | 任意发布失败都能定位到具体发布对象 |
| P0 | 发布主链路补 `devflow.project.id` `devflow.application.id` `devflow.environment.id` `devflow.release.id` | Traces | 服务 | 能按一次发布把整条链路串起来 |
| P0 | 补 `release.LoadApplicationContext` `release.CreateManifest` `tekton.TriggerPipelineRun` `release.RenderBundle` `argocd.CreateApplication` | Traces | 服务 | 能分清卡在上下文加载、构建、渲染还是部署 |
| P0 | 禁止把 `devflow.release.id` 打成高频 Metrics label | Metrics | 服务 / 平台 | 保证发布指标仍可聚合，不被对象 ID 打碎 |
| P1 | 补 `devflow.manifest.id` `devflow.intent.kind` `devflow.intent.status` | Traces / Logs | 服务 | 能分清是哪个 manifest、哪种意图、当前状态如何 |
| P1 | 发布阶段耗时分段指标单独暴露 | Metrics | 服务 | 不进 Trace 也能先判断哪一段变慢 |
| P1 | 运行时回写与发布链路打通到 `runtime-service.WatchReleaseStatus` | Traces | 服务 | 发布结束前后是同一条可排障链路 |

### runtime-service

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | HTTP 指标补齐最小三元标签 | Metrics | 框架 / middleware | 运维 API、查询 API 有稳定错误率和时延视图 |
| P0 | runtime 状态与操作日志补 `trace_id` `span_id` `devflow.application.id` `message` | Logs | 框架 + 服务 | Pod / workload 问题能回到单次操作和单次请求 |
| P0 | rollout 观察和回写链路补 `devflow.application.id` `devflow.environment.id` `devflow.release.id` | Traces / Logs | 服务 | 能知道是哪次发布、哪个环境、哪个应用的 runtime 异常 |
| P0 | 补 `runtime.ListWorkloads` `runtime.ListPods` `runtime.WriteReleaseStatusBack` 这类关键 span | Traces | 服务 | 能分清是观察慢、Pod 未就绪，还是回写失败 |
| P1 | 补 `k8s.workload.kind` `k8s.workload.name` 和运维动作结果 `result` | Logs / Traces | 服务 | 能知道影响的是哪类 workload、操作是否成功 |
| P1 | 删除 Pod、重启、扩缩容成功率指标单独暴露 | Metrics | 服务 | 值班时可快速看到运维动作异常率 |

---

## 📌 平台统一整改项

下面这些项不应该拆给单个服务自己兜底，而应由平台统一整改：

| 优先级 | 整改项 | Signal | 默认 owner | 验收目标 |
|--------|--------|--------|------------|----------|
| P0 | 统一 Resource 中的 `service.name` `service.namespace` `service.version` | Traces / Metrics / Logs | SDK / 平台模板 | 五个服务身份口径一致 |
| P0 | 统一 Collector enrichment 的 `deployment.environment.name` `k8s.*` | Traces / Logs | Collector | 环境与运行落点字段不再由服务手工双写 |
| P0 | 统一 HTTP access / error log 最小字段集 | Logs | 框架模板 / 平台日志库 | 五个服务入口日志格式一致 |
| P0 | 统一禁止项：`trace_id` / `span_id` / `devflow.*.id` 不进高频 Metrics label，不进 Loki label | Metrics / Logs | 平台规范 | 防止高基数爆炸 |
| P1 | 统一 `build_info` 或等价版本常量指标，承载 `service.version` 的 Metrics 暴露 | Metrics | 平台模板 / 服务公共库 | 版本信息可查，但不会打碎高频 HTTP 聚合 |
| P1 | 统一 exemplar 和 Metrics -> Trace 跳转能力 | Metrics / Traces | 平台观测链路 | 值班可从聚合点直接进 Trace |

---

## 怎么用这张表

如果你现在的目标是：

- **补某个服务的基础观测**
  - 先补该服务的 P0 字段
  - 再补“整改矩阵”里的 P0 项
  - 再补“建议关键指标”
  - 最后补“推荐日志消息”和“推荐关键 Span”
- **验收发布链路**
  - 优先检查 `release-service` 和 `runtime-service`
  - 再检查 `meta/config/network` 在链路里是否被稳定串联
- **做值班排障**
  - 先按服务定位到对应章节
  - 再确认字段是否足以支持从指标跳 Trace，再跳日志

---

## 关联阅读

- [字段命名与来源边界](../contracts/attributes/)
- [结构化日志规范](../contracts/logging/)
- [Go 服务最小 OTel 接入示例](../go-example/)
