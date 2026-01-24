
---
title: "Component"
date: 2026-01-04
categories:
  - Cloud Native
  - DevOps
tags:
  - Kubernetes
  - DevOps
  - Observability
---


### Metrics

| 组件                  | 领域          | 解决的问题             | 定位    | 是否必选 | 替代方案            |
|---------------------|-------------|-------------------|-------|------|-----------------|
| Prometheus          | Metrics     | 指标采集与查询           | 指标引擎  | ✅    | VictoriaMetrics |
| Prometheus Operator | 运维自动化       | Prometheus 生命周期管理 | 控制器   | ❌    | 手动部署            |
| kube-state-metrics  | K8s Metrics | Kubernetes 状态指标   | 指标源   | ✅    | 无               |
| node-exporter       | 主机监控        | Node 资源指标         | 指标采集器 | ✅    | 无               |

### Logs

| 组件            | 领域   | 解决的问题      | 定位       | 是否必选 | 替代方案              |
|---------------|------|------------|----------|------|-------------------|
| Loki          | Logs | 低成本日志存储与查询 | 日志系统     | ❌    | ELK、OpenSearch    |
| Alloy / Agent | Logs | 日志采集       | 采集 Agent | ❌    | Fluent Bit、Vector |

### Tracing

| 组件            | 领域        | 解决的问题  | 定位       | 是否必选 | 替代方案            |
|---------------|-----------|--------|----------|------|-----------------|
| Tempo         | Tracing   | 分布式追踪  | Trace 存储 | ❌    | Jaeger          |
| OpenTelemetry | Telemetry | 统一采集标准 | 采集规范     | ✅    | OpenTracing（过时） |

### Visualization

| 组件      | 领域  | 解决的问题                      | 定位     | 是否必选 | 替代方案   |
|---------|-----|----------------------------|--------|------|--------|
| Grafana | 可视化 | Metrics / Logs / Traces 展示 | 统一观测入口 | ✅    | Kibana |

