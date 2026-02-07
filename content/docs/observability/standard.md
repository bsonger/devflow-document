# 🏷️ Observability Labels / Attributes 规范

本文档定义了 **Metric / Trace / Log** 的标准 Labels / Attributes，用于统一收集、查询和关联数据。  
其中 Labels / Attributes 主要分为两类：  
- **必选**：核心维度，用于聚合和拆分指标  
- **可选**：辅助维度，可用于多集群、多环境、灰度或团队统计  

---

## ✅ 实践建议

- 统一 `service.name`、`deployment.environment` 与 `trace_id`，保证三者可关联  
- 监控查询以 `service.name + http.route` 为首要维度  
- 生产环境避免高基数字段（如 userId / requestId）  

## 1️⃣ Metric

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


### 可选 Labels(强烈)
| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|----|
| `deployment.environment` | string | 部署环境 | `prod` / `staging` |
| `trace_id` | string | Trace ID（可选，用于关联 Metric 和 Trace） | `2e71abb92e031efc2a7a1c4280959f4b` |
| `k8s.namespace.name` | string | K8s 命名空间 | `applications` |
| `k8s.pod.name` | string | Pod 名称 | `user-service-5c7d8b9d7f-xyz12` |
| `k8s.container.name` | string | 容器名称 | `user-service` |
| `k8s.node.name` | string | 节点名称 | `node-01` | 
| `region` / `zone` | string | 地域 / 可用区 | `ap-southeast-1a` |


### Metric Value / Measurement
| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `http.server.duration` | duration | 请求耗时 | `120ms` |
| `http.request.size` | bytes | 请求大小 | `2KB` |
| `http.response.size` | bytes | 响应大小 | `10KB` |

---

## 2️⃣ Trace

**用于分布式请求链路追踪**

### span Attributes
## 🧷 Span Attributes
**Span 关注单次操作的上下文和状态，用于 Trace 追踪**

### 必选
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

### 可选
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

#### 2️⃣ Resource Attributes（Span 所属资源，如 Pod / VM / Node）
**表示 Span 或 Metric 所运行的物理/虚拟资源上下文，包括服务和 Kubernetes 信息**

### 必选
| Key | 类型 | 说明 | 示例 |
|-----|-----|-----|-----|
| `service.name` | string | 服务名称 | `devflow` |
| `deployment.environment` | string | 部署环境 | `prod` / `staging` / `dev` |
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `applications` |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` |
| `k8s.container.name` | string | 容器名称 | `devflow` |

### 可选
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

## 3️⃣ Log

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
