---
title: "可观测性组件矩阵"
weight: 71
---

# 可观测性技术栈

DevFlow 的可观测性由三个支柱组成：Metrics（指标）、Logs（日志）、Traces（链路）。每个支柱有专门的工具负责采集、存储和展示。

---

## Metrics — 系统的体检报告

**Prometheus** 负责采集和存储指标。DevFlow 所有服务都暴露 `/metrics` 端点，Prometheus 定期来"查房"。

**Grafana** 负责展示。预置了 10+ 个仪表盘：
- 服务概览（QPS、延迟、错误率）
- 发布流水线（构建、渲染、部署各阶段耗时）
- 运行时状态（Pod 状态、资源使用）

### Metrics 组件矩阵

| 组件                  | 领域          | 解决的问题             | 定位    | 是否必选 | 替代方案            |
|---------------------|-------------|-------------------|-------|------|-----------------|
| Prometheus          | Metrics     | 指标采集与查询           | 指标引擎  | ✅    | VictoriaMetrics |
| Prometheus Operator | 运维自动化       | Prometheus 生命周期管理 | 控制器   | ❌    | 手动部署            |
| kube-state-metrics  | K8s Metrics | Kubernetes 状态指标   | 指标源   | ✅    | 无               |
| node-exporter       | 主机监控        | Node 资源指标         | 指标采集器 | ✅    | 无               |

---

## Logs — 系统的日记

**Grafana Loki** 负责存储和查询日志。不像传统 ELK 那么重，Loki 只索引标签，不索引日志内容，更省资源。

**Grafana Alloy**（原 Grafana Agent）负责在各节点采集日志，发送到 Loki。

### Logs 组件矩阵

| 组件            | 领域   | 解决的问题      | 定位       | 是否必选 | 替代方案              |
|---------------|------|------------|----------|------|-------------------|
| Loki          | Logs | 低成本日志存储与查询 | 日志系统     | ❌    | ELK、OpenSearch    |
| Alloy / Agent | Logs | 日志采集       | 采集 Agent | ❌    | Fluent Bit、Vector |

---

## Traces — 请求的足迹

**OpenTelemetry** 负责采集链路数据。一个请求从进来到出去，经过了哪些服务、每个服务花了多少时间，全部记录下来。

**Signoz** 负责存储和展示链路数据，支持按服务、接口、耗时筛选。

### Tracing 组件矩阵

| 组件            | 领域        | 解决的问题  | 定位       | 是否必选 | 替代方案            |
|---------------|-----------|--------|----------|------|-----------------|
| Tempo         | Tracing   | 分布式追踪  | Trace 存储 | ❌    | Jaeger          |
| OpenTelemetry | Telemetry | 统一采集标准 | 采集规范     | ✅    | OpenTracing（过时） |

---

## Visualization — 统一观测入口

**Grafana** 是 Metrics / Logs / Traces 的统一展示入口。一个界面就能看到系统的全貌。

### Visualization 组件矩阵

| 组件      | 领域  | 解决的问题                      | 定位     | 是否必选 | 替代方案   |
|---------|-----|----------------------------|--------|------|--------|
| Grafana | 可视化 | Metrics / Logs / Traces 展示 | 统一观测入口 | ✅    | Kibana |

---

## 一个请求的完整观测

当一个请求进入 DevFlow：

1. **Gateway** 接收请求，生成 trace_id
2. 请求经过各个服务，每个服务记录：
   - Metrics：QPS、延迟、错误率
   - Logs：业务日志（带上 trace_id）
   - Traces：调用链路（每个服务的耗时）
3. 出问题排查时：
   - 从 Grafana 看到错误率飙升（Metrics）
   - 从 trace_id 找到对应链路（Traces）
   - 从链路找到具体服务的日志（Logs）

三个支柱互相关联，形成一个完整的观测闭环。
