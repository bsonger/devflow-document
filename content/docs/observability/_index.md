---
title: "可观测性"
weight: 70
---

# 📡 可观测性

发布过程中出了问题，你怎么知道？发布后性能有没有下降？DevFlow 通过 Metrics、Logs、Traces 三个维度，让你对系统状态了如指掌。

---

## 🧱 三大支柱

### 📈 Metrics（指标）— 系统的体检报告

CPU 用了多少？请求延迟多少？错误率有没有飙升？

DevFlow 所有服务都通过 {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus 暴露指标，在 {{< brand-icon name="grafana" alt="Grafana" >}} Grafana 里能看到完整的仪表盘。

### 📜 Logs（日志）— 系统的日记

应用打印了哪些日志？有没有报错？

通过 Loki 统一收集，按服务、级别、关键词检索，再由 {{< brand-icon name="grafana" alt="Grafana" >}} Grafana 展示。

### 🧵 Traces（链路）— 请求的足迹

一个请求从进来到出去，经过了哪些服务？每个服务花了多少时间？

通过 {{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} OpenTelemetry 自动采集，结合 Tempo / Grafana 查看完整链路。

---

## 🏷️ 标签到底该配在哪

Observability 里最容易混乱的一点，不是“字段叫什么”，而是“**该谁来配**”。

| 类型 | 举例 | 配置位置 | 负责人 |
|------|------|----------|--------|
| 服务启动标签 | `service.name` `service.version` `deployment.environment` | 服务 Deployment / SDK 初始化 | 平台模板 + 服务配置 |
| 服务业务标签 | `devflow.application.id` `devflow.release.id` `error.message` | 服务代码 | 服务开发者 |
| 平台公共标签 | `k8s.pod.name` `k8s.namespace.name` `k8s.cluster.name` | OTel Collector | SRE / 平台组 |

建议先读 [Attributes 规范](attributes/)，再看 [Labels 规范](standard/)。

## 👀 DevFlow 中的可观测性

### 🚀 发布过程中看什么

| 👁️ 看什么 | 🛠️ 工具 | 🎯 目的 |
|--------|------|------|
| 构建耗时 | {{< brand-icon name="tekton" alt="Tekton" >}} Tekton Dashboard | CI 流水线是否变慢 |
| 发布进度 | DevFlow Console | 当前在哪个阶段 |
| Pod 状态 | runtime-service | 新版本是否正常运行 |
| 流量切换 | {{< brand-icon name="grafana" alt="Grafana" >}} Grafana + {{< brand-icon name="istio" alt="Istio" >}} Istio | Canary 灰度是否正常 |
| 错误率 | {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus + {{< brand-icon name="grafana" alt="Grafana" >}} Grafana | 新版本有没有引入 bug |

### ✅ 发布后看什么

| 👁️ 看什么 | 🛠️ 工具 | 🎯 目的 |
|--------|------|------|
| 请求延迟 | {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus | 性能有没有退化 |
| 错误率 | {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus | 稳定性如何 |
| 资源使用 | {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus | 需不需要扩容 |
| 业务指标 | {{< brand-icon name="prometheus" alt="Prometheus" >}} Prometheus | 转化率、成交额等 |

---

## 🧭 文档导航

| 📄 文档 | 📝 内容 |
|------|------|
| [组件矩阵](component/) | 可观测性技术栈详细对比 |
| [Attributes 规范](attributes/) | 统一的标签命名规范 |
| [Labels 规范](standard/) | Metric / Trace / Log 的标准字段完整定义 |
| [Collector 模板](collector/) | OTel Collector 的推荐配置模板 |
| [Go 接入示例](go-example/) | Go 服务最小 OTel 接入示例 |
| [结构化日志规范](logging/) | DevFlow 日志字段与级别建议 |
| [服务字段清单](service-checklist/) | 五大服务该打哪些关键观测字段 |
| [OTel 接入检查清单](onboarding-checklist/) | 新服务接入 observability 的最小验收清单 |
| [发布链路 Trace 示例](release-trace-example/) | 用一条完整发布链路说明 Trace / Log / Metric 如何串联排障 |
| [Collector 生产排障 Runbook](collector-runbook/) | 线上 observability 断流、缺字段、延迟升高时的值班排障顺序 |
| [发布失败排障剧本](release-failure-playbook/) | 按 Tekton / Render / OCI / Argo CD / Runtime 五段拆解发布失败排查 |
