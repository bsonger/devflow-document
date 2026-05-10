---
title: "公共 Attributes"
weight: 72
---

# 🏷️ 公共 Attributes

DevFlow 的所有服务使用统一的标签（Attributes），这样 Metrics、Logs、Traces 才能互相关联。

---

## 为什么要统一

假设 meta-service 的一个请求出错了：

- Metrics 里记录了这个接口的延迟
- Logs 里记录了错误详情
- Traces 里记录了整个调用链路

如果三个系统用的标签名字不一样，你就没法把它们串起来。统一标签后，通过 `trace_id` 就能从 Metrics 跳到 Trace，再跳到 Log。

---

## 字段来源说明

DevFlow 的 Attributes 来自两个渠道：

| 来源 | 说明 | 谁负责 | 是否需要代码改动 |
|------|------|--------|-----------------|
| **OTel 自动采集** | OpenTelemetry SDK / Collector 自动注入 | 基础设施（SRE/平台组） | ❌ 不需要 |
| **服务自行添加** | 开发者在代码中显式设置 | 各服务团队 | ✅ 需要 |

### 快速对照表

| 字段 | 来源 | 谁来配置 |
|------|------|---------|
| `service.name` / `service.version` / `service.instance.id` | OTel SDK 自动从环境变量读取 | 基础设施配置环境变量 |
| `k8s.*`（Pod、Namespace、Node 等） | OTel Collector `k8sattributes` Processor 自动采集 | 基础设施配置 Collector |
| `http.*`（method、route、status_code 等） | OTel HTTP Instrumentation 自动从请求中采集 | ❌ 自动 |
| `span.*` / `trace.id` | OTel SDK 自动生成 | ❌ 自动 |
| `devflow.*`（project、application、environment、release 等） | 服务代码中手动设置 | **各服务开发者** |
| `db.*`（system、statement、operation） | 服务代码中手动设置（或使用 ORM 插件自动） | **各服务开发者** |
| `messaging.*`（system、destination、operation） | 服务代码中手动设置（或使用消息队列插件自动） | **各服务开发者** |

---

## OTel 自动注入的 Attributes

这些字段由 OpenTelemetry SDK 或 Collector 自动采集，**服务代码中不需要手动设置**。

### 服务资源信息（Resource Attributes）

OTel SDK 启动时会自动从环境变量、K8s Downward API 等渠道采集：

| Key | 类型 | 说明 | 示例 | 注入方式 |
|-----|-----|-----|------|---------|
| `service.name` | string | 服务名称 | `meta-service` | `OTEL_SERVICE_NAME` 环境变量 |
| `service.version` | string | 服务版本 | `v1.2.3` | `OTEL_RESOURCE_ATTRIBUTES` 环境变量 |
| `service.instance.id` | string | Pod 名称 | `meta-service-abc123` | K8s Downward API 自动注入 |
| `service.namespace` | string | 服务命名空间 | `devflow` | `OTEL_RESOURCE_ATTRIBUTES` 环境变量 |
| `deployment.environment` | string | 部署环境 | `prod` / `staging` | `OTEL_RESOURCE_ATTRIBUTES` 环境变量 |

### Kubernetes 信息（Resource Attributes）

OTel Collector 的 `k8sattributes` Processor 会自动从 K8s API 采集：

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|------|
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `devflow` |
| `k8s.pod.name` | string | Pod 名称 | `meta-service-12345` |
| `k8s.container.name` | string | 容器名称 | `meta-service` |
| `k8s.node.name` | string | 节点名称 | `node-01` |

### HTTP 请求信息（Span Attributes）

OTel HTTP Instrumentation 自动从请求中采集：

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|------|
| `http.method` | string | HTTP 方法 | `GET` |
| `http.route` | string | 请求路由模板 | `/api/v1/meta/projects` |
| `http.status_code` | int | 响应状态码 | `200` |
| `http.url` | string | 完整请求 URL | `https://devflow.bei.com/api/v1/meta/projects` |

### Span 链路信息（Span Attributes）

OTel SDK 自动为每个 Span 生成：

| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|------|
| `span.kind` | string | Span 类型 | `server` / `client` / `internal` |
| `span.id` | string | 当前 Span ID | `a1b2c3d4e5f6` |
| `trace.id` | string | Trace ID | `abc123def456` |

---

## 服务自行添加的 Attributes

这些字段需要在**代码中显式设置**，OTel 不会自动采集。

### 业务上下文

| Key | 类型 | 说明 | 示例 | 添加位置 |
|-----|-----|-----|------|---------|
| `devflow.project.id` | string | Project ID | `proj-123` | 接口入口 Span |
| `devflow.application.id` | string | Application ID | `app-456` | 接口入口 Span |
| `devflow.environment.id` | string | Environment ID | `env-789` | 接口入口 Span |
| `devflow.release.id` | string | Release ID | `rel-abc` | 发布相关 Span |
| `devflow.user.id` | string | 操作者用户 ID | `user-001` | 接口入口 Span |

### 数据库操作

| Key | 类型 | 说明 | 示例 | 添加位置 |
|-----|-----|-----|------|---------|
| `db.system` | string | 数据库类型 | `postgresql` | 数据库 Span |
| `db.statement` | string | SQL 语句（脱敏） | `SELECT * FROM projects` | 数据库 Span |
| `db.operation` | string | 操作类型 | `SELECT` / `INSERT` | 数据库 Span |

### 队列/消息

| Key | 类型 | 说明 | 示例 | 添加位置 |
|-----|-----|-----|------|---------|
| `messaging.system` | string | 消息系统 | `kafka` / `rabbitmq` | 消息 Span |
| `messaging.destination` | string | 队列/Topic 名称 | `build-events` | 消息 Span |
| `messaging.operation` | string | 操作类型 | `publish` / `receive` | 消息 Span |

---

## 统一规范

1. **同一请求生命周期**内的 **Metric / Log / Trace** 应共享以下 Attributes：
   - `service.name`
   - `service.version`
   - `service.instance.id`
   - `deployment.environment`
   - `k8s.pod.name`
   - `trace_id`（如果有 Trace）

2. **命名规范**：
   - Attribute 使用 **小写 + 点号分隔** (`service.name`)
   - Kubernetes 相关字段加前缀 `k8s.`
   - HTTP 相关字段加前缀 `http.`
   - 日志相关字段加前缀 `log.`
   - Span 相关字段加前缀 `span.`
   - DevFlow 业务字段加前缀 `devflow.`

3. **来源要求**：
   - OTel 自动注入的字段：**不要**在代码中重复设置
   - 服务自行添加的字段：在关键 Span 上统一设置

---

## 命名规则速查

- 全部 **小写**
- 层级用 **点号** 分隔：`service.name`、`k8s.pod.name`
- 不要用驼峰：`serviceName` ❌

---

## 来源

OTel 自动注入的字段通过环境变量配置：

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "meta-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=production"
```

服务自行添加的字段在代码中设置（以 Go 为例）：

```go
span.SetAttributes(
    attribute.String("devflow.project.id", projectID),
    attribute.String("devflow.application.id", appID),
)
```
