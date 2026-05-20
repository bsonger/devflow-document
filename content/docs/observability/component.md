---
title: "可观测性技术栈与组件矩阵"
weight: 71
---

# 📡 可观测性技术栈与组件矩阵

<span class="df-badge">{{< brand-icon name="prometheus" alt="Prometheus" >}} Metrics</span> <span class="df-badge">📜 Logs</span> <span class="df-badge">{{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} Traces</span> <span class="df-badge">{{< brand-icon name="grafana" alt="Grafana" >}} Grafana</span>

DevFlow 的可观测性不是“堆几个监控组件”这么简单，它要服务于三类真实问题：

1. 五个服务自己的 API 和异步任务是否正常
2. 一次发布从入口到回写是否能串成同一条排障链路
3. 线上 runtime 异常时能否快速定位到具体 workload、pod 和阶段

所以这里不仅要看工具，还要看这些工具在 DevFlow 里的分工。

---

## DevFlow 里的三条主观测路径

### 路径 1：服务 API 入口

主要覆盖：

- `meta-service`
- `config-service`
- `network-service`
- `release-service`
- `runtime-service`

主要回答：

- 哪个接口慢了
- 哪个接口错误率升高
- 哪个请求对应哪条日志和 Trace

### 路径 2：发布编排链路

主要覆盖：

- `release-service` 收集上下文
- 触发 Tekton 构建
- 渲染部署包
- 推送 OCI bundle
- 创建或更新 Argo CD / Rollout 相关资源

主要回答：

- 这次发布卡在哪一阶段
- 是构建慢、渲染慢，还是部署反馈慢
- 是否能按 `devflow.release.id` 把整次发布查完整

### 路径 3：运行时状态回写

主要覆盖：

- `runtime-service` 观察 workload / pod
- rollout 进度回写
- 运维操作执行结果

主要回答：

- 当前 Pod 到底有没有 Ready
- rollout 为什么卡住
- 手工删除 Pod / 重启 / 扩缩容是否成功

---

## 📈 Metrics — 系统的体检报告

**{{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus** 负责采集和存储指标。DevFlow 各服务暴露 `/metrics`，Prometheus 定期拉取，用来回答“哪里开始变坏了”。

**{{< brand-icon name="grafana" alt="Grafana" >}} Grafana** 负责展示。对于 DevFlow，最重要的不是“图多”，而是至少能看三类视图：

- 服务入口视图：QPS、延迟、错误率
- 发布视图：构建、渲染、部署、回写各阶段耗时和失败率
- 运行时视图：workload 健康、Pod 状态、运维操作结果

### Metrics 组件矩阵

| 组件                  | 领域          | 解决的问题             | 定位    | 是否必选 | 替代方案            |
|---------------------|-------------|-------------------|-------|------|-----------------|
| {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus          | Metrics     | 指标采集与查询           | 指标引擎  | ✅    | VictoriaMetrics |
| {{< brand-icon name="prometheus" alt="Prometheus Operator" >}} Prometheus Operator | 运维自动化       | Prometheus 生命周期管理 | 控制器   | ❌    | 手动部署            |
| {{< brand-icon name="kubernetes" alt="Kubernetes" >}} kube-state-metrics  | K8s Metrics | Kubernetes 状态指标   | 指标源   | ✅    | 无               |
| node-exporter       | 主机监控        | Node 资源指标         | 指标采集器 | ✅    | 无               |

### DevFlow 最关心的指标面

| 观测面 | 应优先回答的问题 |
|------|----------------|
| 服务 API 指标 | 哪个服务、哪个路由开始变慢或报错 |
| 发布阶段指标 | Manifest 创建、渲染、部署、回写哪一段失败率最高 |
| runtime 指标 | Pod readiness、重启、运行状态是否异常 |

---

## 📜 Logs — 系统的日记

**📘 Loki** 负责存储和查询日志。在 DevFlow 里，日志不是为了“什么都记”，而是为了给 Trace 和指标补细节。

**Grafana Alloy**（原 Grafana Agent）负责在各节点采集日志，发送到 Loki。

### Logs 组件矩阵

| 组件            | 领域   | 解决的问题      | 定位       | 是否必选 | 替代方案              |
|---------------|------|------------|----------|------|-------------------|
| Loki          | Logs | 低成本日志存储与查询 | 日志系统     | ❌    | ELK、OpenSearch    |
| {{< brand-icon name="grafana" alt="Grafana Alloy" >}} Alloy / Agent | Logs | 日志采集       | 采集 Agent | ❌    | Fluent Bit、Vector |

### DevFlow 里日志最重要的三类内容

| 日志类型 | 典型来源 | 主要价值 |
|--------|--------|--------|
| HTTP 访问 / 错误日志 | 五个服务入口 API | 从 `trace_id` 反查请求细节 |
| 生命周期日志 | `release-service`、`runtime-service` | 看发布、回写、操作执行到了哪一步 |
| 业务变更日志 | `meta/config/network` | 看哪个对象被创建、变更、绑定 |

---

## 🧵 Traces — 请求的足迹

**{{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} OpenTelemetry** 负责采集链路数据。对于 DevFlow，Trace 最重要的作用不是画漂亮瀑布图，而是让你知道一次发布或一次 API 请求到底卡在哪个服务、哪个阶段。

**⏱️ Tempo** 负责存储 Trace 数据，再由 {{< brand-icon name="grafana" alt="Grafana" >}} Grafana 统一展示和关联分析。

### Tracing 组件矩阵

| 组件            | 领域        | 解决的问题  | 定位       | 是否必选 | 替代方案            |
|---------------|-----------|--------|----------|------|-----------------|
| Tempo         | Tracing   | 分布式追踪  | Trace 存储 | ❌    | Jaeger          |
| {{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} OpenTelemetry | Telemetry | 统一采集标准 | 采集规范     | ✅    | OpenTracing（过时） |

### DevFlow 里最关键的 Trace

| Trace 类型 | 根入口 | 至少应该串到哪里 |
|----------|------|----------------|
| 普通 API Trace | 五个服务的 HTTP API | 当前服务内部关键步骤 |
| 发布链路 Trace | `release-service` 发布入口 | `meta/config/network` 读取、构建触发、部署、runtime 回写 |
| 运维操作 Trace | `runtime-service` 操作入口 | workload / pod 查询、K8s API 调用、结果回写 |

---

## 🖥️ Visualization — 统一观测入口

**{{< brand-icon name="grafana" alt="Grafana" >}} Grafana** 是 Metrics / Logs / Traces 的统一展示入口。一个界面就能看到系统的全貌。

### Visualization 组件矩阵

| 组件      | 领域  | 解决的问题                      | 定位     | 是否必选 | 替代方案   |
|---------|-----|----------------------------|--------|------|--------|
| {{< brand-icon name="grafana" alt="Grafana" >}} Grafana | 可视化 | Metrics / Logs / Traces 展示 | 统一观测入口 | ✅    | Kibana |

---

## 🔍 一个请求的完整观测

当一个普通请求进入 DevFlow：

1. **Gateway 或服务入口** 接收请求，生成 `trace_id`
2. 请求经过各个服务，每个服务记录：
   - Metrics：QPS、延迟、错误率
   - Logs：关键日志（带上 `trace_id` / `span_id`）
   - Traces：调用链路（每个步骤的耗时）
3. 出问题排查时：
   - 从 Grafana 看到错误率飙升（Metrics）
   - 从 trace_id 找到对应链路（Traces）
   - 从链路找到具体服务的日志（Logs）

三个支柱互相关联，形成一个完整的观测闭环。

---

## 🔍 一次发布的完整观测

当一次发布进入 DevFlow：

1. `release-service` 生成根 Trace，并挂上 `devflow.application.id`、`devflow.environment.id`、`devflow.release.id`
2. 它依次读取元数据、配置、网络信息，创建 Manifest / Release，触发构建和部署
3. `runtime-service` 继续提供 rollout 状态和 workload / pod 观察结果
4. 排障时：
   - 先从发布失败率或阶段耗时看哪一段异常
   - 再进入对应 Trace
   - 最后按 `trace_id` 和 `devflow.release.id` 查日志细节

如果这条链路不能串起来，DevFlow 的发布排障效率会明显下降。
