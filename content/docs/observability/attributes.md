---
title: "公共 Attributes"
weight: 72
---

# 公共 Attributes

DevFlow 的所有服务使用统一的标签（Attributes），这样 Metrics、Logs、Traces 才能互相关联。

---

## 为什么要统一

假设 meta-service 的一个请求出错了：

- Metrics 里记录了这个接口的延迟
- Logs 里记录了错误详情
- Traces 里记录了整个调用链路

如果三个系统用的标签名字不一样，你就没法把它们串起来。统一标签后，通过 `trace_id` 就能从 Metrics 跳到 Trace，再跳到 Log。

---

## 服务相关 Attributes（公共）

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `service.name` | string | 服务名称 | `devflow` | Metric / Log / Trace |
| `service.version` | string | 服务版本 | `v1.2.3` | Metric / Log / Trace |
| `service.instance.id` | string | 服务实例 ID 或 Pod 名称 | `devflow-abc123` | Metric / Log / Trace |
| `service.namespace` | string | 服务命名空间 | `payments`| Metric / Log / Trace |
| `deployment.environment` | string | 部署环境 | `prod` / `staging` / `dev` | Metric / Log / Trace |

---

## Kubernetes 相关 Attributes（公共）

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` | Metric / Log / Trace |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `applications` | Metric / Log / Trace |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` | Metric / Log / Trace |
| `k8s.container.name` | string | 容器名称 | `devflow` | Metric / Log / Trace |
| `k8s.node.name` | string | 节点名称 | `node-01` | Metric / Log / Trace |

---

## 请求信息

| 标签 | 例子 | 说明 |
|------|------|------|
| `http.method` | GET | HTTP 方法 |
| `http.route` | /api/v1/meta/projects | 请求路径 |
| `http.status_code` | 200 | 响应状态码 |

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

3. **来源要求**：
   - 所有 Attribute 应来源于 **环境变量** 或 **资源信息**，避免硬编码。

---

## 命名规则速查

- 全部 **小写**
- 层级用 **点号** 分隔：`service.name`、`k8s.pod.name`
- 不要用驼峰：`serviceName` ❌

---

## 来源

这些标签通过环境变量注入到服务中：

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "meta-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=production"
```
