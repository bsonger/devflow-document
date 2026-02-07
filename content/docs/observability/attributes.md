---
title: "Attributes"
---

# 🧾 公共 Attributes 速查

本页提供跨 Metric / Log / Trace 的公共字段清单，便于统一采集与关联查询。

## 🧩 1. 服务相关 Attributes (公共)

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `service.name` | string | 服务名称 | `devflow` | Metric / Log / Trace |
| `service.version` | string | 服务版本 | `v1.2.3` | Metric / Log / Trace |
| `service.instance.id` | string | 服务实例 ID 或 Pod 名称 | `devflow-abc123` | Metric / Log / Trace |
| `service.namespace` | string | 服务命名空间 | `payments`| Metric / Log / Trace |
| `deployment.environment` | string | 部署环境 | `prod` / `staging` / `dev` | Metric / Log / Trace |

---

## 🧩 2. Kubernetes 相关 Attributes (公共)

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` | Metric / Log / Trace |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `applications` | Metric / Log / Trace |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` | Metric / Log / Trace |
| `k8s.container.name` | string | 容器名称 | `devflow` | Metric / Log / Trace |
| `k8s.node.name` | string | 节点名称 | `node-01` | Metric / Log / Trace |

---

## ✅ 3. 统一规范

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
