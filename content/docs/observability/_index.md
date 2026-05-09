---
title: "可观测性"
weight: 70
---

# 可观测性

发布过程中出了问题，你怎么知道？发布后性能有没有下降？DevFlow 通过 Metrics、Logs、Traces 三个维度，让你对系统状态了如指掌。

---

## 三大支柱

### Metrics（指标）— 系统的体检报告

CPU 用了多少？请求延迟多少？错误率有没有飙升？

DevFlow 所有服务都通过 Prometheus 暴露指标，Grafana 里能看到完整的仪表盘。

### Logs（日志）— 系统的日记

应用打印了哪些日志？有没有报错？

通过 Grafana Loki 统一收集，按服务、级别、关键词检索。

### Traces（链路）— 请求的足迹

一个请求从进来到出去，经过了哪些服务？每个服务花了多少时间？

通过 OpenTelemetry 自动采集，Signoz 中查看完整链路。

---

## DevFlow 中的可观测性

### 发布过程中看什么

| 看什么 | 工具 | 目的 |
|--------|------|------|
| 构建耗时 | Tekton Dashboard | CI 流水线是否变慢 |
| 发布进度 | DevFlow Console | 当前在哪个阶段 |
| Pod 状态 | runtime-service | 新版本是否正常运行 |
| 流量切换 | Grafana + Istio | Canary 灰度是否正常 |
| 错误率 | Prometheus + Grafana | 新版本有没有引入 bug |

### 发布后看什么

| 看什么 | 工具 | 目的 |
|--------|------|------|
| 请求延迟 | Prometheus | 性能有没有退化 |
| 错误率 | Prometheus | 稳定性如何 |
| 资源使用 | Prometheus | 需不需要扩容 |
| 业务指标 | Prometheus | 转化率、成交额等 |

---

## 文档导航

| 文档 | 内容 |
|------|------|
| [组件矩阵](component/) | 可观测性技术栈 |
| [Attributes 规范](attributes/) | 统一的标签命名规范 |
| [Labels 规范](standard/) | Metric / Trace / Log 的标准字段 |
