---
title: "Service 与 Route"
weight: 45
---

# Service 与 Route

## Service — 应用的网络拓扑

**Service** 定义了应用暴露了哪些端口，用什么协议。

### 例子

```yaml
name: order-service
ports:
  - name: http
    port: 80
    target_port: 8080
    protocol: HTTP
  - name: grpc
    port: 9090
    target_port: 9090
    protocol: GRPC
```

这表示 order-service 有两个端口：
- HTTP 服务在 80 端口（容器内是 8080）
- GRPC 服务在 9090 端口

### 它会映射成什么

DevFlow 会把 Service 定义映射成 Kubernetes Service：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
```

### 重要特性：不随环境变化

Service 是应用的固有属性。不管部署到测试还是生产，应用暴露的端口是一样的。

---

## Route — 环境的入口规则

**Route** 定义了外部流量怎么访问到这个应用的这个环境。

### 例子

**生产环境的 Route：**

```yaml
host: "order.example.com"
path: "/api/v1"
service_name: "order-service"
service_port: 80
tls:
  enabled: true
  secret_name: "order-tls"
```

这表示：访问 `order.example.com/api/v1` 的请求，会被转发到 `order-service` 的 80 端口，且启用了 HTTPS。

**测试环境的 Route：**

```yaml
host: "order-test.example.com"
path: "/api/v1"
service_name: "order-service"
service_port: 80
tls:
  enabled: false
```

测试环境用不同的域名，且不启用 HTTPS。

### 它会映射成什么

DevFlow 会把 Route 映射成 Istio VirtualService + Gateway（或 Kubernetes Ingress）：

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
    - "order.example.com"
  http:
    - match:
        - uri:
            prefix: "/api/v1"
      route:
        - destination:
            host: order-service
            port:
              number: 80
```

---

## 为什么拆成两层

| | Service | Route |
|--|---------|-------|
| 属于 | Application | ApplicationEnvironment |
| 定义什么 | 应用暴露哪些端口 | 外部怎么访问 |
| 随环境变化 | 否 | 是 |
| 类比 | 房子的门 | 门牌号和钥匙 |

分开的好处：
- Service 定义一次，所有环境复用
- Route 随环境变化，测试用测试域名，生产用生产域名
- 职责清晰，不会搞混

---

## 与发布策略的关系

Route 是流量控制的基础：

- **Canary** — 通过 Istio VirtualService 的权重控制流量比例
- **Blue-Green** — 通过 Service Selector 切换流量指向

没有 Route 定义，流量控制就无从谈起。
