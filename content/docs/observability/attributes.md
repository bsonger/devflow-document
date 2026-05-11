---
title: "公共 Attributes"
weight: 72
---

# 公共 Attributes

DevFlow 的 Metrics、Logs、Traces 需要能关联，但三者不应该机械地重复同一份字段。
这页定义的是“公共命名和来源边界”，不是要求每种信号都带完全一样的属性。

---

## 为什么要统一

假设 meta-service 的一个请求出错了：

- Metrics 里记录了这个接口的延迟
- Logs 里记录了错误详情
- Traces 里记录了整个调用链路

如果三个系统用的标签名字不一样，就没法稳定串联。统一命名后，可以从
Metrics 发现问题，通过 exemplar 跳到 Trace，再按 `trace_id` 跳到 Log。

如果你当前要回答“每种信号最低限度必须带哪些字段”，不要只看这页，
直接去 [信号标签矩阵](../signal-label-matrix/)；这页主要定义命名和来源边界。

职责边界：

- Metrics：看 rate / error / latency / SLO
- Traces：看调用链、慢点、下游瓶颈
- Logs：看错误文本、业务事件、panic 细节

---

## 服务相关 Attributes

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `service.name` | string | 服务名称 | `release-service` | Trace / Resource |
| `service.version` | string | 服务版本 | `2026.05.11` | Trace / Resource |
| `service.instance.id` | string | 服务实例 ID 或 Pod 名称 | `devflow-abc123` | Trace |
| `service.namespace` | string | 服务命名空间 | `devflow` | Trace / Resource |
| `deployment.environment.name` | string | 部署环境 | `production` / `pre-production` | Trace / Resource |

说明：

- 这些字段优先作为 OpenTelemetry Resource Attributes 存在。
- 普通 HTTP access log 不要求在每条记录中重复带 `service.name`、`service.namespace`、`service.version`、`deployment.environment.name`。
- Prometheus metrics 使用 Prometheus-safe label 名称，例如 `service_name`。

---

## Kubernetes / Host / Cloud Attributes

| Key | 类型 | 说明 | 示例 | 适用类型 |
|-----|-----|-----|-----|---------|
| `k8s.cluster.name` | string | 集群名称 | `cluster-prod` | Collector-enriched Log / Trace |
| `k8s.namespace.name` | string | Pod 所在命名空间 | `devflow` | Collector-enriched Log / Trace |
| `k8s.pod.name` | string | Pod 名称 | `devflow-12345` | Collector-enriched Log / Trace |
| `k8s.container.name` | string | 容器名称 | `devflow` | Collector-enriched Log / Trace |
| `k8s.node.name` | string | 节点名称 | `node-01` | Collector-enriched Log / Trace |
| `host.name` | string | 主机名 | `worker-01` | Collector-enriched Log / Trace |
| `cloud.provider` | string | 云厂商 | `alicloud` | Collector-enriched Log / Trace |
| `cloud.region` | string | 地域 | `cn-hangzhou` | Collector-enriched Log / Trace |

这些字段应由 OpenTelemetry Collector 补充，不应在业务代码中硬编码。

原因很简单：这些字段描述的是运行时落点，不是业务事实。服务镜像滚动、Pod 重建、节点漂移后，这些值都可能变化。

---

## 请求相关 Attributes

| 标签 | 例子 | 说明 |
|------|------|------|
| `http.request.method` | `GET` | HTTP 方法 |
| `http.route` | `/api/v1/projects/:id` | 路由模板 |
| `http.response.status_code` | `200` | 响应状态码 |
| `url.path` | `/api/v1/projects/123` | 实际请求路径 |

说明：

- `http.route` 必须是模板路由，不要把原始动态路径拿去做 metrics label。
- `url.path` 可以出现在 log 和 trace 中，但不应进入高频 metrics label。
- 如果是 HTTP metrics，当前 DevFlow 还要求 `http_response_status_class` 作为必需维度存在。

---

## 统一规范

1. **同一请求生命周期**内的三种信号应共享最小关联语义，而不是共享全部字段：
   - `service.name` / `service_name`
   - `http.route` / `http_route`
   - `http.response.status_code` / `http_response_status_code`
   - `http_response_status_class`（仅 Metrics）
   - `trace_id`（仅 Trace / Log / exemplar，不是 metrics label）

2. **命名规范**：
   - Attribute 使用 **小写 + 点号分隔** (`service.name`)
   - Kubernetes 相关字段加前缀 `k8s.`
   - HTTP 相关字段加前缀 `http.`
   - 日志相关字段加前缀 `log.`
   - Span 相关字段加前缀 `span.`

3. **来源要求**：
   - 服务资源字段优先来自环境变量和 OTel Resource Attributes
   - `trace_id` / `span_id` 优先来自当前 span context
   - `trace_id` / `span_id` 在新日志契约里应视为必需字段
   - Kubernetes / Host / Cloud 字段优先由 Collector 补充
   - 不要在业务代码里硬编码 Pod、Node、Cluster、Cloud 信息

4. **高基数字段限制**：
   - `trace_id`、`span_id`、`request_id`、`user_id`、`release_id`、原始 `url.path` 都不应进入高频 metrics label
   - Metrics 到 Trace 的跳转应使用 exemplar
   - `release_id` 更适合放在 Trace、Log、DevFlow DB 或低频 info/status metric

---

## 命名规则速查

- 全部 **小写**
- 层级用 **点号** 分隔：`service.name`、`k8s.pod.name`
- 不要用驼峰：`serviceName` ❌

---

## 当前推荐来源

这些标签通常通过环境变量和 OTel 配置注入到服务中：

```yaml
env:
  - name: SERVICE_NAME
    value: "release-service"
  - name: OTEL_SERVICE_NAMESPACE
    value: "devflow"
  - name: SERVICE_VERSION
    value: "2026.05.11"
```

补充说明：

- `SERVICE_VERSION` 不建议直接使用完整镜像 digest 作为服务版本展示值。
- 完整镜像 digest 更适合放在镜像元数据或部署系统里，而不是作为业务侧主版本标识。
