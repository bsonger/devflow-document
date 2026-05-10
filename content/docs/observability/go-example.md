---
title: "Go 服务最小 OTel 接入示例"
weight: 76
---

# 🧪 Go 服务最小 OTel 接入示例

<span class="df-badge">Go</span> <span class="df-badge">OTLP</span> <span class="df-badge">Gin</span> <span class="df-badge">devflow.*</span>

如果前面几页回答的是：

- 标签该放哪
- Collector 怎么配
- Metrics / Logs / Traces 应该长什么样

那这一页回答的是最后一步：

> **一个 Go 服务到底要怎么最小成本接进来？**

目标很明确：

1. 服务启动时带上统一 Resource Attributes
2. 请求进入时自动生成 Trace
3. 在业务代码里补充 `devflow.*` 标签
4. 把数据通过 OTLP 发给 OTel Collector

---

## 🎯 最小接入目标

接入完成后，一个请求至少应该具备这些信息：

| 层级 | 字段 |
|------|------|
| 服务启动配置 | `service.name` `service.version` |
| Collector 注入 | `k8s.cluster.name` `k8s.namespace.name` `k8s.pod.name` |
| 服务代码设置 | `devflow.application.id` `devflow.release.id` |
| 自动生成 | `trace_id` `span_id` `http.method` `http.route` |

如果这几组字段都齐了，Grafana / Tempo / Loki 里的关联基本就能跑通。

---

## 📦 建议依赖

下面示例假设你使用：

- `gin` 作为 HTTP 框架
- OpenTelemetry Go SDK
- OTLP gRPC exporter

```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/sdk/resource
go get go.opentelemetry.io/otel/sdk/trace
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
go get go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin
```

---

## ⚙️ 第一步：Deployment 环境变量

先把“服务是谁”这组字段在启动时配好。

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector.observability.svc.cluster.local:4317
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: grpc
  - name: SERVICE_NAME
    value: release-service
  - name: OTEL_SERVICE_NAMESPACE
    value: devflow
  - name: SERVICE_VERSION
    value: 1.4.2
```

这一层只负责：

- `service.name`
- `service.version`
- `service.namespace`

`deployment.environment.name` 如果平台已经通过 OTel Collector 统一注入，就不要再让每个服务重复维护；只有平台暂时做不到时，才在这里兜底。

不要在这里塞 `devflow.release.id` 这类请求级字段。

---

## 🧱 第二步：初始化 Tracer Provider

```go
package observability

import (
    "context"
    "fmt"
    "os"
    "time"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    sdkresource "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func InitOTel(ctx context.Context) (func(context.Context) error, error) {
    endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    serviceName := os.Getenv("SERVICE_NAME")
    if serviceName == "" {
        serviceName = os.Getenv("OTEL_SERVICE_NAME")
    }

    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(endpoint),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, fmt.Errorf("create otlp exporter: %w", err)
    }

    res, err := sdkresource.New(ctx,
        sdkresource.WithFromEnv(),
        sdkresource.WithTelemetrySDK(),
        sdkresource.WithAttributes(
            semconv.ServiceName(serviceName),
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("create resource: %w", err)
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(1.0))),
    )

    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(
        propagation.NewCompositeTextMapPropagator(
            propagation.TraceContext{},
            propagation.Baggage{},
        ),
    )

    return func(ctx context.Context) error {
        shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
        defer cancel()
        return tp.Shutdown(shutdownCtx)
    }, nil
}
```

这一步负责把 Trace 导到 Collector，不负责业务标签。

---

## 🌐 第三步：给 Gin 自动挂 HTTP Trace

```go
package main

import (
    "context"
    "log"

    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

func main() {
    shutdown, err := observability.InitOTel(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    defer shutdown(context.Background())

    r := gin.Default()
    r.Use(otelgin.Middleware("release-service"))

    r.GET("/api/v1/releases/:id", getRelease)
    _ = r.Run(":8080")
}
```

有了这层 middleware，通常会自动拿到：

- `trace_id`
- `span_id`
- `http.method`
- `http.route`
- `http.status_code`

---

## ✍️ 第四步：在业务代码里补 `devflow.*`

这一层最关键，因为 Collector 不知道你正在处理哪个 Release。

```go
package main

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/trace"
)

func getRelease(c *gin.Context) {
    ctx := c.Request.Context()
    span := trace.SpanFromContext(ctx)

    releaseID := c.Param("id")
    applicationID := c.Query("application_id")

    span.SetAttributes(
        attribute.String("devflow.release.id", releaseID),
        attribute.String("devflow.application.id", applicationID),
    )

    c.JSON(http.StatusOK, gin.H{
        "id": releaseID,
    })
}
```

这一步就是“服务代码设置”的典型例子。

---

## 🪵 第五步：日志里也带同一组字段

如果你的日志系统支持结构化字段，推荐至少打上：

- `trace_id`
- `devflow.application.id`
- `devflow.release.id`
- `service.name`

示例：

```go
logger.Info("release fetched",
    "trace_id", trace.SpanContextFromContext(ctx).TraceID().String(),
    "devflow.application.id", applicationID,
    "devflow.release.id", releaseID,
)
```

这样从 Trace 跳日志时，能直接对齐到同一个业务对象。

---

## 📈 第六步：业务指标不要乱打高基数标签

很多 Go 服务接 OTel 后，最容易犯的错不是 Trace，而是 Metrics label 爆炸。

### 推荐

- `service_name`
- `deployment_environment_name`
- `http_route`
- `http_response_status_code`

### 不推荐

- `user_id`
- `request_id`
- `release_id`（除非你非常明确知道存储成本）
- 原始 URL / query string

简单理解：

- **Trace / Log** 适合细粒度对象 ID
- **Metric** 适合聚合维度

---

## ✅ 一个完整请求最终应该长什么样

### 服务启动层

- `service.name=release-service`
- `service.version=1.4.2`

### Collector 层

- `deployment.environment.name=prod`
- `k8s.cluster.name=devflow-prod`
- `k8s.namespace.name=devflow`
- `k8s.pod.name=release-service-xxxx`

### 业务代码层

- `devflow.application.id=app-123`
- `devflow.release.id=rel-456`

### 自动采集层

- `trace_id=...`
- `span_id=...`
- `http.request.method=GET`
- `http.route=/api/v1/releases/:id`

---

## 🚫 常见错误

### 错误 1：把 `release_id` 写进 `OTEL_RESOURCE_ATTRIBUTES`

问题：它不是进程级稳定属性，而是请求级字段。

### 错误 2：完全不在业务代码里补 `devflow.*`

问题：Telemetry 有了，但只能看到“哪个服务慢”，看不到“哪个 Release 慢”。

### 错误 3：日志和 Trace 字段名不一致

问题：Trace 里叫 `devflow.release.id`，日志里叫 `releaseId`，关联会变差。

### 错误 4：所有业务字段都打进 Metrics

问题：Prometheus label 基数会迅速失控。

---

## 🧭 推荐落地顺序

1. 先把 Deployment 环境变量配好
2. 再把 OTLP exporter 接到 Collector
3. 然后用 `otelgin` 先拿到基础 HTTP Span
4. 最后补 `devflow.*` 业务字段

这样排查问题时也更简单：

- 先确认有没有 Trace
- 再确认 Resource Attributes 对不对
- 最后确认业务标签有没有打上

---

## 关联阅读

- [公共 Attributes](../attributes/)
- [Labels / Attributes 规范](../standard/)
- [OTel Collector 配置模板](../collector/)
