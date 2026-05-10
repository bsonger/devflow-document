---
title: "公共 Attributes"
weight: 72
---

# 🏷️ 公共 Attributes

<span class="df-badge">⚙️ 服务启动配置</span> <span class="df-badge">✍️ 服务代码设置</span> <span class="df-badge">🧰 Collector 公共注入</span>

DevFlow 的 observability 文档需要先回答一个最实际的问题：**一个标签到底该配在哪里？**

这页把 Attributes 拆成 3 类：

1. **服务启动时配置的标签**：服务自己不在业务代码里写死，而是通过环境变量/SDK 初始化统一带上
2. **服务在代码里主动设置的标签**：和业务对象、发布流程、错误上下文强相关，只有服务自己知道
3. **OTel Collector 统一补充的公共标签**：和运行环境、Kubernetes 元数据相关，适合由平台侧集中注入

---

## 🧭 先记结论

| 类别 | 典型字段 | 配置位置 | 谁负责 |
|------|----------|----------|--------|
| **服务启动配置** | `service.name` `service.version` `deployment.environment` | Deployment 环境变量 / SDK Resource 初始化 | 服务模板 / 平台基础设施 |
| **服务代码设置** | `devflow.application.id` `devflow.release.id` `error.message` | 业务代码里的 Span / Log / Metric | 各服务开发者 |
| **Collector 公共注入** | `k8s.pod.name` `k8s.namespace.name` `k8s.node.name` `k8s.cluster.name` | OTel Collector Processor | SRE / 平台组 |

一句话判断：

- **和“这个服务是谁”有关** → 服务启动配置
- **和“这次请求/发布在处理什么业务对象”有关** → 服务代码设置
- **和“这个 Pod 跑在哪个集群节点上”有关** → Collector 注入

---

## ① 服务启动配置的标签

这类标签通常属于 **Resource Attributes**。

特点：

- 每个进程启动后基本不变
- 不应该在每个请求里重复手动 `SetAttributes`
- 最适合通过环境变量或 SDK 初始化统一设置

### 推荐字段

| Key | 说明 | 推荐来源 | 示例 |
|-----|------|----------|------|
| `service.name` | 服务名 | `OTEL_SERVICE_NAME` | `meta-service` |
| `service.version` | 当前发布版本 | `OTEL_RESOURCE_ATTRIBUTES` | `1.4.2` |
| `service.namespace` | 逻辑服务域/业务域 | `OTEL_RESOURCE_ATTRIBUTES` | `devflow` |
| `service.instance.id` | 实例唯一标识 | Downward API / Pod 名 | `meta-service-7f8c9d` |
| `deployment.environment` | 部署环境 | `OTEL_RESOURCE_ATTRIBUTES` | `prod` |

### 这类字段应该怎么配

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "meta-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.4.2,service.namespace=devflow,deployment.environment=prod"
```

### 规则

- 这类字段**不要在业务代码里每次请求重复设置**
- 平台最好提供统一 Helm / Kustomize 模板，避免每个服务各写一套

---

## ② 服务代码里主动设置的标签

这类标签只有业务代码自己知道，OTel SDK 和 Collector 都推不出来。

特点：

- 和当前请求、当前发布、当前资源对象强相关
- 值通常随请求变化
- 最适合挂在关键 Span、结构化日志、业务指标上

### 推荐字段

#### DevFlow 业务上下文

| Key | 说明 | 应该由谁设置 | 典型位置 |
|-----|------|--------------|----------|
| `devflow.project.id` | 当前项目 | 服务代码 | 入口 Span / 关键日志 |
| `devflow.application.id` | 当前应用 | 服务代码 | 入口 Span / 关键日志 |
| `devflow.environment.id` | 当前环境 | 服务代码 | 发布相关 Span |
| `devflow.manifest.id` | 当前构建快照 | 服务代码 | release-service 构建链路 |
| `devflow.release.id` | 当前发布快照 | 服务代码 | release-service / runtime-service |
| `devflow.cluster.id` | 当前目标集群 | 服务代码 | 发布 / runtime 相关 Span |
| `devflow.user.id` | 操作者 | 服务代码 | API 入口日志 / 审计 Span |

#### 错误与业务事件

| Key | 说明 | 典型位置 |
|-----|------|----------|
| `error.message` | 错误描述 | error log / failed span |
| `error.type` | 错误类型 | error log / failed span |
| `devflow.intent.kind` | 异步任务类型 | worker span |
| `devflow.intent.status` | 异步任务状态 | worker span |

#### 下游依赖上下文

| Key | 说明 | 典型位置 |
|-----|------|----------|
| `db.operation` | SQL 操作类型 | DB span |
| `messaging.system` | 消息系统 | MQ span |
| `messaging.destination` | 队列/Topic | MQ span |

### Go 示例

```go
span.SetAttributes(
    attribute.String("devflow.project.id", projectID),
    attribute.String("devflow.application.id", appID),
    attribute.String("devflow.release.id", releaseID),
)

logger.Info("release started",
    "devflow.project.id", projectID,
    "devflow.application.id", appID,
    "devflow.release.id", releaseID,
)
```

### 规则

- 业务标签优先使用 `devflow.*` 前缀
- 只在**关键 Span / 关键日志 / 关键指标**上打，不要无脑全量铺
- 高基数字段不要进 Metrics labels，例如 `user_id`、`request_id`、自由文本错误

---

## ③ OTel Collector 统一补充的公共标签

这类字段来自运行环境，最适合由平台统一注入。

特点：

- 服务代码拿得到，但不应该每个服务自己写一遍
- 不同语言、不同框架都该拿到同一份结果
- 最典型的是 Kubernetes 元数据 enrichment

### 推荐由 Collector 注入的字段

| Key | 说明 | 典型 Processor |
|-----|------|-----------------|
| `k8s.cluster.name` | 集群名 | `resource` / `attributes` |
| `k8s.namespace.name` | Namespace | `k8sattributes` |
| `k8s.pod.name` | Pod 名 | `k8sattributes` |
| `k8s.container.name` | 容器名 | `k8sattributes` |
| `k8s.node.name` | 节点名 | `k8sattributes` |
| `k8s.deployment.name` | Deployment 名 | `k8sattributes` |
| `cloud.region` / `cloud.availability_zone` | 地域 / 可用区 | `resource` |

### Collector 配置示意

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.container.name
        - k8s.node.name
        - k8s.deployment.name

  resource:
    attributes:
      - key: k8s.cluster.name
        value: prod-cluster
        action: upsert
      - key: cloud.region
        value: cn-hangzhou
        action: upsert
```

### 规则

- **Kubernetes 元数据尽量不要服务自己写**
- 集群名、地域、可用区这类平台公共标签，统一由 Collector 或网关注入
- Collector 负责的是“运行环境补充”，**不要把业务 ID 逻辑搬到 Collector 里做**

---

## 🚫 哪些不要放进 Collector

下面这些字段虽然很重要，但**不适合**让 Collector 猜或统一生成：

| 字段 | 为什么不适合 |
|------|--------------|
| `devflow.application.id` | Collector 不知道当前请求绑定的是哪个应用对象 |
| `devflow.release.id` | 只有业务逻辑知道当前处理的是哪个 Release |
| `devflow.manifest.id` | 不是运行时基础设施元数据 |
| `error.message` | 属于业务错误上下文 |
| `db.statement` | 属于具体依赖调用内容 |

Collector 不应该承担业务语义推断。

---

## 🧩 推荐职责分层

### 服务模板 / 基础设施统一做

- `OTEL_SERVICE_NAME`
- `OTEL_RESOURCE_ATTRIBUTES`
- exporter endpoint
- propagators
- sampling 基础策略

### 各服务开发者在代码里做

- `devflow.*` 业务上下文
- 错误上下文
- 异步 worker / 发布流程上下文
- 关键业务指标 label 选择

### SRE / 平台组在 Collector 里做

- `k8sattributes`
- 集群 / 地域公共标签补齐
- 多租户环境下统一脱敏、过滤、路由
- logs / traces / metrics 的统一 pipeline

---

## ✅ 最终判断清单

遇到一个新标签时，可以这样判断：

1. **它是否在整个进程生命周期里基本不变？**
   - 是 → 放服务启动配置
2. **它是否只和当前请求/业务对象有关？**
   - 是 → 放服务代码里
3. **它是否属于 Kubernetes / 云环境公共元数据？**
   - 是 → 放 Collector 里
4. **Collector 能不能仅靠运行环境可靠拿到它？**
   - 不能 → 不要放 Collector

---

## 关联阅读

- [Labels / Attributes 规范](../standard/)
- [可观测性组件矩阵](../component/)
