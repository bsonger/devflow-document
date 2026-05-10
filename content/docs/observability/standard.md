---
title: "Labels / Attributes 规范"
weight: 73
---

# 🏷️ 标签使用规范

<span class="df-badge">{{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} OTel</span> <span class="df-badge">Metrics</span> <span class="df-badge">Logs</span> <span class="df-badge">Traces</span>

DevFlow 的 Metrics、Traces、Logs 使用统一的标签体系，确保三者可以互相关联。

本文档定义了 **Metric / Trace / Log** 的标准 Labels / Attributes，用于统一收集、查询和关联数据。

其中 Labels / Attributes 主要分为两类：
- **必选**：核心维度，用于聚合和拆分指标
- **可选**：辅助维度，可用于多集群、多环境、灰度或团队统计

> **来源标注**：本文档中字段来源分为两类 — `🤖 OTel 自动`（SDK/Collector 自动注入，无需代码改动）和 `✍️ 手动添加`（需在代码中显式设置）。

## 🧭 先分清“在哪配置”

在 DevFlow 里，标签来源建议按三层理解：

| 层级 | 典型字段 | 配置位置 |
|------|----------|----------|
| 服务启动层 | `service.name` `service.version` `deployment.environment` | SDK Resource / 环境变量 |
| 服务代码层 | `devflow.*` `error.message` `db.operation` | Span / Log / Metric 代码 |
| Collector 层 | `k8s.*` `cloud.region` | OTel Collector processors |

如果你先关心“字段应该放哪”，优先看 [公共 Attributes](../attributes/)。

---

## 📈 Metrics（指标）标签

**用于统计和聚合指标数据**

### 必选 Labels

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `metric.name` | string | 指标名称 | `http_request_duration_seconds` |
| `service.name` | string | 服务名称 | `user-service` |
| `http.method` | string | HTTP 方法 | `GET` |
| `http.route` | string | 路由模板 | `/users/:id` |
| `http.status_code` | int | HTTP 状态码 | `200` |
| `k8s.cluster.name` | string | 集群名称或 ID | `k8s-prod-01` |

### 可选 Labels（强烈建议）

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|----|
| `deployment.environment` | string | 部署环境 | `prod` / `staging` |
| `trace_id` | string | Trace ID（可选，用于关联 Metric 和 Trace） | `2e71abb92e031efc2a7a1c4280959f4b` |
| `k8s.namespace.name` | string | K8s 命名空间 | `applications` |
| `k8s.pod.name` | string | Pod 名称 | `user-service-5c7d8b9d7f-xyz12` |
| `k8s.container.name` | string | 容器名称 | `user-service` |
| `k8s.node.name` | string | 节点名称 | `node-01` |
| `region` / `zone` | string | 地域 / 可用区 | `ap-southeast-1a` |

### 不能作为标签的字段

有些字段不适合做标签，因为值太多会导致存储爆炸：

| 字段 | 为什么不行 |
|------|-----------|
| `user_id` | 用户可能有几千万，每个用户一条时间线 |
| `request_id` | 每个请求唯一，基数无限 |
| `ip_address` | IP 数量无界 |

这些字段应该放在 Logs 或 Traces 里，而不是 Metrics 标签里。

### Metric Value / Measurement

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `http.server.duration` | duration | 请求耗时 | `120ms` |
| `http.request.size` | bytes | 请求大小 | `2KB` |
| `http.response.size` | bytes | 响应大小 | `10KB` |

---

## 🔗 Traces（链路）标签

**用于分布式请求链路追踪**

### Span Attributes

**Span 关注单次操作的上下文和状态，用于 Trace 追踪**

#### 必选

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `trace_id` | string | Trace ID，用于关联整个 Trace | `2e71abb92e031efc2a7a1c4280959f4b` |
| `span_id` | string | 当前 Span ID | `abc123def456` |
| `span.name` | string | Span 名称 | `Tekton.CreatePipelineRun` |
| `span.kind` | string | Span 类型 | `server` / `client` / `producer` / `consumer` |
| `span.status` | string | Span 状态 | `ok` / `error` |
| `span.duration` | duration | Span 耗时 | `120ms` |
| `http.method` | string | HTTP 方法 | `GET` |
| `http.route` | string | 路由模板 | `/users/:id` |
| `http.status_code` | int | HTTP 状态码 | `200` |
| `url.path` | string | 请求路径 | `/api/v1/users/123` |
| `url.scheme` | string | 协议 | `http` / `https` |

#### 可选

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `parent_span_id` | string | 父 Span ID | `xyz789ghi012` |
| `client.address` | string | 客户端 IP 或地址 | `10.0.0.1` |
| `server.address` | string | 服务端 IP 或地址 | `10.0.0.10` |
| `network.peer.address` | string | 网络对端地址 | `10.0.0.2` |
| `network.peer.port` | int | 网络对端端口 | `443` |
| `network.protocol.version` | string | 网络协议版本 | `HTTP/2` |
| `http.response.body.size` | int | 响应体大小 | `1024` |
| `error.message` | string | 错误信息（如有） | `database timeout` |
| `user_agent.original` | string | User-Agent | `curl/7.68.0` |

#### 业务上下文

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `devflow.application.id` | string | 涉及哪个应用 | `app-123` |
| `devflow.manifest.id` | string | 涉及哪个构建 | `mf-001` |
| `devflow.release.id` | string | 涉及哪个发布 | `rel-001` |

这样从链路里可以直接看到：这个请求在处理哪个应用的发布。

### Resource Attributes（Span 所属资源，如 Pod / VM / Node）

**表示 Span 或 Metric 所运行的物理/虚拟资源上下文，包括服务和 Kubernetes 信息**

#### 必选

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `service.name` | string | 服务名称 | `devflow` |
| `deployment.environment` | string | 部署环境 | `prod` / `staging` / `dev` |
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `applications` |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` |
| `k8s.container.name` | string | 容器名称 | `devflow` |

#### 可选

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `service.namespace` | string | 服务命名空间（业务层） | `payments` |
| `service.instance.id` | string | 服务实例 ID 或 Pod 名称 | `devflow-abc123` |
| `service.version` | string | 服务版本 | `v1.2.3` |
| `k8s.node.name` | string | 节点名称 | `node-01` |
| `k8s.region` | string | 集群所在地域 | `ap-southeast-1` |
| `k8s.zone` | string | 集群可用区 | `ap-southeast-1a` |
| `k8s.host.id` | string | 节点/主机 ID | `i-0234abcd5678ef` |

---

## 📜 Logs（日志）标签

**用于记录系统或业务日志**

### 必选 Attributes

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `log.level` | string | 日志级别 | `INFO` / `WARN` / `ERROR` |
| `log.message` | string | 日志内容 | `http request completed` |
| `trace_id` | string | Trace ID（可选，用于关联 Trace / Metric） | `2e71abb92e031efc2a7a1c4280959f4b` |

### 可选 Attributes

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `log.logger` | string | 日志记录器名称 | `gin` / `otelzap` |
| `span_id` | string | Span ID（可选） | `abc123def456` |
| `service.name` | string | 服务名称 | `user-service` |
| `deployment.environment` | string | 部署环境 | `prod` |
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `applications` |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` |
| `k8s.container.name` | string | 容器名称 | `devflow` |
| `k8s.node.name` | string | 节点名称 | `node-01` |
| `k8s.region` | string | 集群所在地域 | `ap-southeast-1` |
| `k8s.zone` | string | 集群可用区 | `ap-southeast-1a` |
| `client.ip` | string | 客户端 IP | `10.0.0.1` |
| `user_agent.original` | string | User-Agent | `curl/7.68.0` |
| `error.message` | string | 错误信息 | `database timeout` |

### Value / Measurement

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `log.stacktrace` | string | 错误堆栈信息（可选） | `at main.go:45` |
| `http.server.duration` | duration | 请求耗时（可选，用于排查慢请求） | `120ms` |

---

## 三者怎么关联

排查问题的典型路径：

1. Grafana 仪表盘看到错误率飙升（Metrics）
2. 点击指标上的 exemplar，跳转到对应 Trace
3. 从 Trace 找到具体服务，再跳转到该服务的 Log

三个系统通过统一的 `trace_id` 和 `service.name` 串在一起。

```mermaid
graph LR
    Metrics["Metrics<br/>看到错误率飙升"] -->|exemplar.trace_id| Trace["Trace<br/>找到具体请求"]
    Trace -->|trace_id| Log["Log<br/>查看错误详情"]
```
